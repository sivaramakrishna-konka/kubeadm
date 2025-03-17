#!/bin/bash

# Create the SSH private key file
cp ${path.module}/siva /home/ubuntu/siva


# Set correct permissions
sudo chmod 400 /home/ubuntu/siva

# Install Ansible
sudo apt update && sudo apt install -y ansible

# Display inventory file
cat /home/ubuntu/inventory.ini

# List contents of /home/ubuntu
ls -l /home/ubuntu/

# Display the private key content (for verification)
cat /home/ubuntu/siva

# Run the Ansible playbook
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/all-nodes-setup.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/master.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/node.yml
