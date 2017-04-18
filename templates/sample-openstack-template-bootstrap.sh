#!/usr/bin/env bash

# Use these commands as a template to create your own Openstack CONS3RT image

# Prerequisites:
# - Python 2.7
# - Openstack unified CLI installed
# - Openstack credentials enabled

echo "Creating server..."

openstack server create --flavor m1.medium --image 3dae6817-36bb-4476-b68f-e743ae5490f3 --key-name default --security-group ssh --nic net-id=a2764a7e-1ced-4208-bbec-cafff31acb72 --user-data ./linux-template-bootstrap.sh joe-ubuntu16

echo "Creating the image..."
#openstack server image create --name "Ubuntu Server 14.04" 38c005e0-273f-42a4-a872-0d268417bc12

echo "Adding image tags..."
#openstack image set --property cons3rtenabled=true

echo "openstack exited with code: $?"
exit 0
