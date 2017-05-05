#!/bin/bash

# Script configuration
templateBuilderIso="TemplateBuilderISO_17.5_04072017b.iso"
downloadUrl="https://s3.amazonaws.com/jackpine-files/${templateBuilderIso}"
swapConfigScript=""
tbDir="/root/tb"

# Configure SSH
/bin/sed -i "/^PasswordAuthentication/d" /etc/ssh/sshd_config
/bin/echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
/bin/sed -i "/^AuthorizedKeysFile/d" /etc/ssh/sshd_config
/bin/echo "AuthorizedKeysFile %h/.ssh/authorized_keys" >> /etc/ssh/sshd_config

# Set up cons3rt user and group
/usr/sbin/groupadd cons3rt
/usr/sbin/useradd -g cons3rt -d "/home/cons3rt" -s "/bin/bash" -c "CONS3RT User" cons3rt
/usr/sbin/usermod -a -G cons3rt cons3rt
/bin/echo 'cons3rt:TMEroot!!' | /usr/sbin/chpasswd
/bin/sed -i "/^cons3rt/d" /etc/sudoers
/bin/echo "cons3rt ALL=(ALL)  ALL" >> /etc/sudoers
/sbin/mkhomedir_helper cons3rt
/bin/mkdir -p /home/cons3rt/.ssh
/bin/touch /home/cons3rt/.ssh/authorized_keys

# Delete UDev Rules
if [ -e /etc/udev/rules.d/70-persistent-net.rules ] ; then
    /bin/rm -Rf /etc/udev/rules.d/70-persistent-net.rules
fi

# Clean up previous Template builder directory
if [ -d ${tbDir} ] ; then
    /bin/rm -Rf ${tbDir}
fi

# Update packages to the latest
if [ -e /usr/bin/yum ] ; then
    /usr/bin/yum -y update
else
    /usr/bin/apt-get -y update
    /usr/bin/apt-get -y upgrade
    # Install Ubuntu GUI
    /usr/bin/apt-get -y install ubuntu-desktop
fi

# Stage the TB 
/bin/mkdir -p ${tbDir}
cd ${tbDir}

# Download Template Builder
/bin/echo "Downloading Template builder: ${downloadUrl}"
/usr/bin/curl -O ${downloadUrl}

# Download the swap config script
/bin/echo "Downloading swap config script: ${swapConfigScript}"
/usr/bin/curl -O ${swapConfigScript}

# Mount the ISO
/bin/echo "Mounting the templace builder ISO..."
/bin/mount -o loop ${templateBuilderIso} /media

# Copy files
/bin/echo "Copying template builder to ${tbDir}..."
/bin/cp -Rf /media/* ${tbDir}/

# Unmount the ISO
/bin/echo "Unmounting the template builder ISO..."
/bin/umount /media

# Configure Swap space


# Run template builder
/bin/echo "Running template builder..."
/bin/chmod +x ${tbDir}/runme.sh
#${tbDir}/runme.sh
#result=$?

# Notify complete
touch /root/USER_DATA_SCRIPT_COMPLETE

# Cleanup
/bin/echo "Cleaning up..."
#rm -Rf ${tbDir}
/bin/echo "Clearing history..."
/bin/cat /dev/null > ~/.bash_history && history -c

# Exit with the Template Builder exit code
exit ${result}
