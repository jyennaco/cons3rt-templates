#!/usr/bin/env bash

subscriptionId="${1}"
appName="${2}"
appUrl="${3}"

echo "Let's create an App Registration for CONS3RT!"

if [ -z "${subscriptionId}" ]; then
    read -p 'Subscription ID: ' subscriptionId
fi
if [ -z "${appName}" ]; then
    read -p 'App Name: ' appName
fi
if [ -z "${appUrl}" ]; then
    read -p 'App URL: ' appUrl
fi

echo "Using subscription ID: ${subscriptionId}"
echo "Creating App Regiatration with name [${appName}] and URL [${appUrl}]"

echo "Setting cloud environment to: AzureUSGovernment"
az cloud set --name AzureUSGovernment

echo "Logging in to Azure (follow instructions)..."
az login

echo "Setting subscription to: ${subscriptionId}"
az account set --subscription ${subscriptionId}
if [ $? -ne 0 ]; then echo "ERROR: Setting subscription to: ${subscriptionId}"; exit 1; fi

echo "Getting the AD tenant ID..."
tenantId=$(az account show --subscription ${subscriptionId} --output yaml | grep 'tenantId' | awk '{print $2}')
if [ -z "${tenantId}" ]; then echo "AD Tenant ID not found!"; exit 1; fi

echo "Using AD Tenant ID: ${tenantId}"

echo "Getting this account service principal name..."
userPrincipalName=$(az ad signed-in-user show --output yaml | grep 'userPrincipalName' | awk '{print $2}')
if [ -z "${userPrincipalName}" ]; then echo "Service principal name not found!"; exit 1; fi

echo "Found Service Principal Name, running as: ${userPrincipalName}"

echo "Get a list of groups for user: ${userPrincipalName}..."
groups=( $(az ad user get-member-groups --upn-or-object-id ${userPrincipalName} | awk '{print $1}') )
echo "Found groups: ${groups[@]}"

echo "Ensure user ${userPrincipalName} has subscription owner permissions or a group does..."
subscriptionRoleVerified=0
subscriptionRole=$(az role assignment list --include-inherited --assignee "${userPrincipalName}" --output table | grep "/subscriptions/${subscriptionId}" | awk '{print $2}')

if [ -z "${subscriptionRole}" ]; then
    echo "Subscription role not found for user: ${userPrincipalName}"
else
    echo "Found subscription role for ${userPrincipalName}: ${subscriptionRole}"
    if [[ ${subscriptionRole} != "Owner" ]]; then
        echo "ERROR: Requires Subscription Owner, found user permission: ${subscriptionRole}"
    else
        echo "User ${userPrincipalName} has the proper Subscription role!"
        subscriptionRoleVerified=1
    fi
fi

if [ ${subscriptionRoleVerified} -eq 0 ]; then
    echo "Checking group permissions..."
    for group in "${groups[@]}"; do
        echo "Checking permissions for group: ${group}..."
        subscriptionRole=$(az role assignment list --include-inherited --all --output table | grep "${group}" | grep -v 'Principal' | grep "/subscriptions/${subscriptionId}" | awk '{print $2}')
        if [ -z "${subscriptionRole}" ]; then
            echo "No subscription permissions found for group: ${group}"
        else
            echo "Found subscription permission for group ${group}: ${subscriptionRole}"
            if [[ ${subscriptionRole} != "Owner" ]]; then
                echo "Requires Subscription Owner, found group permission: ${subscriptionRole}"
            else
                echo "Group ${group} has the proper Subscription role!"
                subscriptionRoleVerified=1
            fi
        fi
    done
fi

if [ ${subscriptionRoleVerified} -eq 0 ]; then
    echo "ERROR: Subscription Owner permissions not found, cannot set up the App Registration permissions properly"
    exit 1
fi

echo "Creating app registration with name [${appName}] and URL [${appUrl}]..."
az ad app create --display-name "${appName}" --homepage "${appUrl}"
if [ $? -ne 0 ]; then echo "ERROR: Unable to create app registration with name [${appName}] and URL [${appUrl}]"; exit 1; fi

echo "Determining the App ID..."
appId=$(az ad app list --display-name ${appName} --output yaml | grep 'appId' | awk '{print $2}')
if [ -z "${appId}" ]; then echo "ERROR: Unable to determine App ID for app registation: ${appName}"; exit 1; fi

echo "Found App ID: ${appId}"

echo "Creating a service principal for App ID: ${appId}..."
az ad sp create --id ${appId} --output yaml
if [ $? -ne 0 ]; then echo "ERROR: Unable to create service principal for app ID: ${appId}"; exit 1; fi

echo "Creating a password for app ID: ${appId}"
appPassword=$(az ad sp credential reset --name ${appId} --credential-description "CONS3RT Login" --output yaml | grep 'password' | awk '{print $2}')
if [ -z "${appPassword}" ]; then echo "ERROR: Unable to create password for App ID: ${appId}"; exit 1; fi

echo "Created app password: ${appPassword}"

echo "Waiting 10 seconds for the app registration to be created..."
sleep 10

echo "Setting permissions for App ID ${appId} to subscription contributor for subscription: ${subscriptionId}"
sleep 1
az role assignment create --assignee ${appId} --scope /subscriptions/${subscriptionId} --role Contributor
if [ $? -ne 0 ]; then echo "ERROR: Unable to set permissions for app ID: ${appId}, to Contributor for subscription: ${subscriptionId}"; exit 1; fi

echo "App Registration for CONS3RT Created!  Plug in the following values to your Azure Cloud in CONS3RT:"
echo "--------------------------"
echo "Application ID: ${appId}"
echo "Subscription ID: ${subscriptionId}"
echo "Secret Key: ${appPassword}"
echo "Tenant Name: ${tenantId}"
echo "--------------------------"

echo "The following IP addresses found to add to the optional External IP Addresses: "
az network public-ip list --output table

echo "Happy CONS3RTing!"
exit 0
