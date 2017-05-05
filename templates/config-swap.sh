#!/usr/bin/env bash

# Created by Joe Yennaco (6/27/15)

# Set log commands
logTag="config-swap"
logInfo="logger -i -s -p local3.info -t ${logTag} [INFO] "
logWarn="logger -i -s -p local3.warning -t ${logTag} [WARNING] "
logErr="logger -i -s -p local3.err -t ${logTag} [ERROR] "

# Get the current timestamp and append to logfile name
TIMESTAMP=$(date "+%Y-%m-%d-%H%M")

######################### GLOBAL VARIABLES #########################

# Array to maintain exit codes of commands
resultSet=();

####################### END GLOBAL VARIABLES #######################

# Executes the passed command, adds the status to the resultSet
# array and return the exit code of the executed command
# Parameters:
# 1 - Command to execute
# Returns:
# Exit code of the command that was executed
function run_and_check_status() {
    "$@"
    local status=$?
    if [ ${status} -ne 0 ] ; then
        ${logErr} "Error executing: $@, exited with code: ${status}"
    else
        ${logInfo} "$@ executed successfully and exited with code: ${status}"
    fi
    resultSet+=("${status}")
    return ${status}
}

# Main install function
# Parameters:
# none
# Returns:
# 0 = Success
# 1 = Non-zero Exit Code found, see cons3rt agent log for more details
function main() {
    ${logInfo} "Beginning swap space configuration ..."
    ${logInfo} "Timestamp: ${TIMESTAMP}"

    if [ -f /swapfile ] ; then
        ${logInfo} "Deleting existing swap file..."
        rm -f /swapfile
    fi

    ${logInfo} "Creating the 4GB swap file /swapfile ..."
    run_and_check_status dd if=/dev/zero of=/swapfile bs=1024 count=4194304

    ${logInfo} "Setting permissions on /swapfile ..."
    run_and_check_status chmod 600 /swapfile

    ${logInfo} "Configuring the /swapfile as swap ..."
    run_and_check_status mkswap /swapfile

    ${logInfo} "Add the swapfile in real time ..."
    run_and_check_status swapon /swapfile

    ${logInfo} "Adding /swapfile to /etc/fstab to re-configure on boot ..."
    sed -i '/swapfile/d' /etc/fstab
    echo "/swapfile    swap    swap   defaults 0 0" >> /etc/fstab

    # Check the results of commands from this script, return error if an
    for resultCheck in "${resultSet[@]}" ; do
        if [ ${resultCheck} -ne 0 ] ; then
            ${logErr} "Non-zero exit code found: ${resultCheck}"
            return 1
        fi
    done

    ${logInfo} "Successfully completed the swap file configuration!"
    return 0
}

main
result=$?

${logInfo} "Exiting with code ${result} ..."
exit ${result}
