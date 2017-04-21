#!/usr/bin/env bash

# Use these commands as a template to create your own Openstack CONS3RT image

# Prerequisites:
# - Python 2.7
# - Openstack unified CLI installed
# - Openstack credentials enabled

flavor="m1.medium"
keyName="default"
securityGroup="ssh"
imageId="3dae6817-36bb-4476-b68f-e743ae5490f3"
networkId="d325c4df-730a-411d-a1b2-fb9ad4a01338"
serverName="joe-ubuntu16"
imageName="Ubuntu Server 16.04"
serverId=""
newImageId=""

echo "Creating server..."
openstack server create --flavor "${flavor}" --image "${imageId}" --key-name "${keyName}" --security-group "${securityGroup}" --nic net-id="${networkId}" --user-data ./linux-template-bootstrap.sh ${serverName}

#echo "Creating the image..."
#openstack server image create --name "${imageName}" "${serverId}"

#echo "Adding image tags..."
#openstack image set --property cons3rtenabled=true ${newImageId}

echo "openstack exited with code: $?"
exit 0
