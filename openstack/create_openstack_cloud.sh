#!/usr/bin/env bash

# Refs:
#   CLI auth: https://docs.openstack.org/python-openstackclient/latest/cli/authentication.html


# User inputs
siteName="${1}"

# Global vars
sharedSubnetCidr="10.10.10.0/24"
sharedSubnetDnsServers=( "8.8.8.8" "8.8.4.4" )

echo "Lets set up OpenStack for CONS3RT!!"

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

# Create the initial shared network
sharedNetworkName="${siteName}_Net_Shared"
echo "Creating network: ${sharedNetworkName}"
openstack network create --no-share ${sharedNetworkName}
if [ $? -ne 0 ]; then echo "Problem creating network: ${sharedNetworkName}"; exit 1; fi
sleep 2

# Create the inital shared subnet
sharedSubnetName="${sharedNetworkName}_subnet"
echo "Creating subnet: ${sharedSubnetName}"

# Compute DNS server options string
dnsOptions=""
for sharedSubnetDnsServer in "${sharedSubnetDnsServers[@]}"; do
    echo "Adding DNS server: ${sharedSubnetDnsServer}"
    dnsOptions+=" --dns-nameserver ${sharedSubnetDnsServer}"
done
echo "Using DNS options: ${dnsOptions}"

sharedSubnet3Octets=$(cut -d '.' -f -3 <<< ${sharedSubnetCidr})
allocationPoolStart="${sharedSubnet3Octets}.1"
allocationPoolEnd="${sharedSubnet3Octets}.253"
sharedSubnetGateway="${sharedSubnet3Octets}.254"

# Create the subnet
subnetOptions="--ip-version 4 --subnet-range ${sharedSubnetCidr} --network ${sharedNetworkName} --gateway ${sharedSubnetGateway} --dhcp --allocation-pool start=${allocationPoolStart},end=${allocationPoolEnd} ${dnsOptions}"
echo "Attempting to create a subnet with options: ${subnetOptions}"
openstack subnet create ${subnetOptions} ${sharedSubnetName}
if [ $? -ne 0 ]; then echo "Problem creating subnet: ${sharedSubnetName}"; exit 2; fi
sleep 2

# Get the subnet ID
echo "Determining the subnet ID for: ${sharedSubnetName}"
subnetId=$(openstack subnet list | grep "${sharedSubnetName}" | awk '{print $2}')
if [ -z "${subnetId}" ]; then echo "Problem getting subnet ID for: ${sharedSubnetName}"; exit 2; fi
echo "Created subnet ID: ${subnetId}"

# Create the router
routerName="${sharedNetworkName}_router"
echo "Creating router: ${routerName}"
openstack router create ${routerName}
if [ $? -ne 0 ]; then echo "Problem creating router: ${routerName}"; exit 3; fi
sleep 2

# Get the router ID
echo "Determining the router ID for: ${routerName}"
routerId=$(openstack router list | grep "${routerName}" | awk '{print $2}')
if [ -z "${routerId}" ]; then echo "Problem getting router ID for: ${routerName}"; exit 2; fi
echo "Created router ID: ${routerId}"

# Add the router to the subnet
echo "Adding subnet ${sharedSubnetName} to router: ${routerName}"
openstack router add subnet ${routerName} ${sharedSubnetName}
if [ $? -ne 0 ]; then echo "Problem adding subnet ${sharedSubnetName} to router: ${routerName}"; exit 4; fi
sleep 2

# Get the default security group ID
echo "Determining the default security group ID..."
defaultSecurityGroupId=$(openstack security group list -f table | grep default | awk '{print $2}')
if [ -z "${defaultSecurityGroupId}" ]; then echo "Default security group ID not found"; exit 5; fi
echo "Found default security group ID: ${defaultSecurityGroupId}"

# Find the port ID that was created
echo "Determining the port ID that was created..."
portId=$(openstack port list | grep "${subnetId}" | grep "${sharedSubnetGateway}" | awk '{print $2}')
if [ -z "${portId}" ]; then echo "Port ID not found for subnet: ${subnetId}"; exit 5; fi
echo "Found port ID: ${portId}"

# Create or update the port
portName="${sharedNetworkName}_port"

# Seems like the port gets created automatically so this is not needed
#portOptions="--network ${sharedNetworkName} --fixed-ip subnet=${sharedSubnetName},ip-address=${sharedSubnetGateway} --security-group ${defaultSecurityGroupId} --disable-port-security"
#echo "Creating port: ${portName} with options: ${portOptions}"
#openstack port create ${portOptions} ${portName}
#if [ $? -ne 0 ]; then echo "Problem creating port: ${portName}"; exit 6; fi

# Add the port to the router
#echo "Adding port ${portName} to router: ${routerName}"
#openstack router add port ${routerName} ${portName}
#if [ $? -ne 0 ]; then echo "Problem adding port ${portName} to router: ${routerName}"; exit 7; fi

# Update the port with a name and default security group
portOptions="--enable-port-security --name ${portName} --security-group ${defaultSecurityGroupId}"
echo "Updating port: ${portId} with options: ${portOptions}"
openstack port set ${portOptions} ${portId}
if [ $? -ne 0 ]; then echo "Problem updating port ID: ${portId}"; exit 5; fi
sleep 2

echo "Completed setting up OpenStack for site: ${siteName}"

authUrl=$(echo ${OS_AUTH_URL} | awk -F // '{print $2}' | awk -F : '{print $1}')
authPort=$(echo ${OS_AUTH_URL} | awk -F // '{print $2}' | awk -F : '{print $2}')

echo "Enter the following values to create your CONS3RT OpenStack cloud:"
echo ""
echo "--------------------------"
echo "Authentication URL: ${authUrl}"
echo "Authentication Port: ${authPort}"
echo "KeyStone Service Version: ${OS_IDENTITY_API_VERSION}"
echo "Username: ${OS_USERNAME}"
echo "Password: ${OS_PASSWORD}"
echo "Domain: ${domainName}"
echo "Tenant Name: ${OS_TENANT_NAME}"
echo "Tenant ID: ${OS_TENANT_ID}"
echo "--------------------------"
echo ""
echo "For the NAT Virtual Machine Image ID, select a Red Hat 6 or 7 from this list:"
openstack image list

echo "Happy CONS3RTing!"
exit 0
