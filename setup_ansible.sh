#!/bin/bash

# Create the SSH private key file
cat <<EOF > /home/ubuntu/siva
${file("${path.module}/siva")}
EOF

# Set correct permissions
sudo chmod 400 /home/ubuntu/siva

# Install Ansible
sudo apt update && sudo apt install -y ansible



# Create inventory file
cat <<EOF > inventory.ini
echo '[master1]' > /home/ubuntu/inventory.ini
echo 'master ansible_host=127.0.0.1 ansible_connection=local' >> /home/ubuntu/inventory.ini

echo '[workers]' >> /home/ubuntu/inventory.ini
echo "worker1 ansible_host=${aws_instance.k8s_nodes["worker1"].private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/siva ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"" >> /home/ubuntu/inventory.ini
echo "worker2 ansible_host=${aws_instance.k8s_nodes["worker2"].private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/siva ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"" >> /home/ubuntu/inventory.ini
EOF

# Display inventory file
cat /home/ubuntu/inventory.ini

# List contents of /home/ubuntu
ls -l /home/ubuntu/

# Display the private key content (for verification)
cat /home/ubuntu/siva

# Compute and display MD5 checksum of private key
md5sum /home/ubuntu/siva

# Generate SSH public key from the private key
ssh-keygen -y -f /home/ubuntu/siva

# Run the Ansible playbook
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/all-nodes-setup.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/master.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/node.yml
