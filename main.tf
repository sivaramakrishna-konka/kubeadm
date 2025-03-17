terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.90.0"
    }
  }
  backend "s3" {
    bucket = "spa-ecs-example-siva"
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
  key_name                    = "siva"
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
      private_key = file("${path.module}/siva")
      host        = aws_instance.k8s_nodes["master"].public_ip
    }
  }

  provisioner "file" {
    source      = "setup_ansible.sh"
    destination = "/home/ubuntu/setup_ansible.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/siva")
      host        = aws_instance.k8s_nodes["master"].public_ip
    }
  }

  # Execute Ansible
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/siva")
      host        = aws_instance.k8s_nodes["master"].public_ip
    }

    inline = [
      "chmod +x /home/ubuntu/setup_ansible.sh",
      "bash /home/ubuntu/setup_ansible.sh"
    ]
  }
}