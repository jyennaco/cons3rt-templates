#!/usr/bin/env bash

# User inputs
siteName="${1}"

# Global vars
sharedSubnetCidr="10.10.10.0/24"
sharedSubnet3Octets=$(cut -d '.' -f -3 <<< ${sharedSubnetCidr})
allocationPoolStart="${sharedSubnet3Octets}.1"
allocationPoolEnd="${sharedSubnet3Octets}.253"
sharedSubnetGateway="${sharedSubnet3Octets}.254"

echo "Deleting a CONS3RT configuration from OpenStack!"

if [ -z "${siteName}" ]; then
    read -p 'CONS3Rt site name abbreviation (e.g. HmC): ' siteName
fi

which openstack >> /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "openstack CLI client not found, to install: https://pypi.org/project/python-openstackclient/"
    echo "Info on setting up authentication: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html"
fi

# Ensure auth environment variables are set
if [ -z "${OS_AUTH_URL}" ]; then
    echo "Auth URL not set: OS_AUTH_URL"
    echo "Info on setting up authentication: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html"
fi
if [ -z "${OS_TENANT_ID}" ]; then
    echo "Auth URL not set: OS_TENANT_ID"
    echo "Info on setting up authentication: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html"
fi
if [ -z "${OS_TENANT_NAME}" ]; then
    echo "Auth URL not set: OS_TENANT_NAME"
    echo "Info on setting up authentication: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html"
fi
if [ -z "${OD_IDENTITY_API_VERSION}" ]; then
    echo "Auth URL not set: OD_IDENTITY_API_VERSION"
    echo "Info on setting up authentication: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html"
fi
if [ -z "${OS_USERNAME}" ]; then
    echo "Auth URL not set: OS_USERNAME"
    echo "Info on setting up authentication: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html"
fi
if [ -z "${OS_PASSWORD}}" ]; then
    echo "Auth URL not set: OS_PASSWORD"
    echo "Info on setting up authentication: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html"
fi
if [ -z "${OS_DOMAIN_NAME}" ]; then
    echo "Auth URL not set: OS_DOMAIN_NAME, using: Default"
    domainName="Default"
else
    domainName="${OS_DOMAIN_NAME}"
fi

# Resource names to remove
sharedNetworkName="${siteName}_Net_Shared"
sharedSubnetName="${sharedNetworkName}_subnet"
routerName="${sharedNetworkName}_router"
portName="${sharedNetworkName}_port"

echo "Removing network and related resources: ${sharedNetworkName}"

echo "Determining resources to delete..."

echo "Determining the network ID for: ${sharedNetworkName}"
networkId=$(openstack network list | grep "${sharedNetworkName}" | awk '{print $2}')

echo "Determining the subnet ID for: ${sharedSubnetName}"
subnetId=$(openstack subnet list | grep "${sharedSubnetName}" | awk '{print $2}')

echo "Determining the router ID for: ${routerName}"
routerId=$(openstack router list | grep "${routerName}" | awk '{print $2}')

echo "Determining the port ID..."
portId=$(openstack port list | grep "${subnetId}" | grep "${sharedSubnetGateway}" | awk '{print $2}')

# Remove and delete the port
if [ -z "${portId}" ]; then
    echo "No port to remove"
else
    echo "Cleaning up port ID: ${portId}"
    if [ -z "${routerId}" ]; then
        echo "No router ID to remove this port from"
    else
        echo "Removing port ${portId} from router: ${routerId}"
        openstack router remove port ${routerId} ${portId}
    fi
fi

# Remove the router
if [ -z "${routerId}" ]; then
    echo "No router to remove"
else
    echo "Cleaning up router ID: ${routerId}"
    openstack router delete ${routerId}
fi

# Remove the subnet
if [ -z "${subnetId}" ]; then
    echo "No subnet to remove"
else
    echo "Cleaning up subnet ID: ${subnetId}"
    openstack subnet delete ${subnetId}
fi

# Remove the network
if [ -z "${networkId}" ]; then
    echo "No network to remove"
else
    echo "Removing network ID: ${networkId}"
    openstack network delete ${networkId}
fi

echo "Completed cleanup for: ${sharedNetworkName}"
exit 0
