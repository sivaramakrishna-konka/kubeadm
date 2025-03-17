# Security Group
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

# Instances
resource "aws_instance" "k8s_nodes" {
  for_each                    = var.instance_types
  ami                         = data.aws_ami.example.id
  instance_type               = each.value
  key_name                    = var.key_name
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

# R53 records
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
  for_each = var.play_book_names

  depends_on = [aws_instance.k8s_nodes]

  triggers = {
    always_run = timestamp()
  }

  # Copy playbooks.yaml
  provisioner "file" {
    source      = "ansible-playbooks/${each.value}"
    destination = "/home/ubuntu/${each.value}"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/siva")
      host        = aws_instance.k8s_nodes["master"].public_ip
    }
  }

  # Copy private key to remote instance
  provisioner "file" {
    source      = "${path.module}/siva.b64"
    destination = "/home/ubuntu/siva.b64"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/siva")
      host        = aws_instance.k8s_nodes["master"].public_ip
    }
  }

  # Copy shell script
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
  # Creating Inventory file
  provisioner "file" {
    content = <<EOT
    [master1]
    master ansible_host=127.0.0.1 ansible_connection=local

    [workers]
    worker1 ansible_host=${aws_instance.k8s_nodes["worker1"].private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/siva ansible_ssh_common_args="-o StrictHostKeyChecking=no"
    worker2 ansible_host=${aws_instance.k8s_nodes["worker2"].private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/siva ansible_ssh_common_args="-o StrictHostKeyChecking=no"
    EOT
    destination = "/home/ubuntu/inventory.ini"
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
      "base64 -d /home/ubuntu/siva.b64 > /home/ubuntu/siva",
      "chmod 400 /home/ubuntu/siva",
      "rm -f /home/ubuntu/siva.b64",
      "chmod +x /home/ubuntu/setup_ansible.sh",
      "bash /home/ubuntu/setup_ansible.sh",
      "echo 'Hello World'",
      "echo 'Hello World!"
    ]
  }
}