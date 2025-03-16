terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.90.0"
    }
  }
  backend "s3" {
    bucket = "spa-ecs-example-siva.pem"
    key    = "kubeadm/terraform.tfstate"
    region = "us-east-1"
  }
}
provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "example" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "k8s_nodes" {
  for_each                    = var.instance_types
  ami                         = data.aws_ami.example.id
  instance_type               = each.value
  key_name                    = "siva.pem"
  security_groups             = [aws_security_group.k8s_sg.name]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
  tags = {
    Name = each.key
  }
}

# sg
resource "aws_security_group" "k8s_sg" {
  name        = "k8s_sg"
  description = "Allow Kubernetes Traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# variables
variable "instance_types" {
  default = {
    "master"  = "t3a.small"
    "worker1" = "t3a.small"
    "worker2" = "t3a.small"
  }
}

# outputs
output "ami_id" {
  value = data.aws_ami.example.id
}

output "public_ips" {
  value = { for k, v in aws_instance.k8s_nodes : k => v.public_ip }
}

output "records" {
  value = { for k, v in aws_route53_record.www : k => v.fqdn }
}

# r53 records
resource "aws_route53_record" "www" {
  for_each = var.instance_types
  zone_id  = "Z011675617HENPLWZ1EJC"
  name     = "${each.key}.konkas.tech"
  type     = "A"
  ttl      = "300"
  records  = [aws_instance.k8s_nodes[each.key].public_ip]
  allow_overwrite = true
}

resource "null_resource" "run_ansible" {
  depends_on = [aws_instance.k8s_nodes]

  # Copy playbook.yaml
  provisioner "file" {
    source      = "playbook.yaml"
    destination = "/home/ubuntu/playbook.yaml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/siva.pem")
      host        = aws_instance.k8s_nodes["master"].public_ip
    }
  }

  # Execute Ansible
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/siva.pem")
      host        = aws_instance.k8s_nodes["master"].public_ip
    }

    inline = [
      "cat <<EOF > /home/ubuntu/siva.pem",
      "${file("${path.module}/siva.pem")}",
      "EOF",
      "sudo chmod 400 /home/ubuntu/siva.pem",
      "sudo apt update && sudo apt install -y ansible",
      "echo '[master1]' > /home/ubuntu/inventory.ini",
      "echo 'master ansible_host=127.0.0.1 ansible_connection=local' >> /home/ubuntu/inventory.ini",
      "echo '[workers]' >> /home/ubuntu/inventory.ini",
      "echo 'worker1 ansible_host=${aws_instance.k8s_nodes["worker1"].private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/siva.pem ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"' >> /home/ubuntu/inventory.ini",
      "echo 'worker2 ansible_host=${aws_instance.k8s_nodes["worker2"].private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/siva.pem ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"' >> /home/ubuntu/inventory.ini",
      "cat /home/ubuntu/inventory.ini",
      "ls -l /home/ubuntu/",
      "cat /home/ubuntu/siva.pem",
      "md5sum /home/ubuntu/siva.pem",
      "ssh-keygen -y -f /home/ubuntu/siva.pem",
      "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/playbook.yaml"
    ]
  }
}