#!/bin/bash

sudo apt update && sudo apt install -y ansible


cat /home/ubuntu/inventory.ini


ls -l /home/ubuntu/


cat /home/ubuntu/siva

# # Run the Ansible playbook
# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/all-nodes-setup.yml
# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/master.yml
# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i /home/ubuntu/inventory.ini /home/ubuntu/node.yml
