#!/bin/bash

# Script configuration
templateBuilderIso="TemplateBuilderISO_17.5_04072017b.iso"
downloadUrl="https://s3.amazonaws.com/jackpine-files/${templateBuilderIso}"
tbDir="/root/tb"

# Delete UDev Rules
if [ -e /etc/udev/rules.d/70-persistent-net.rules ] ; then
    rm -Rf /etc/udev/rules.d/70-persistent-net.rules
fi

# Clean up previous Template builder directory
if [ -d ${tbDir} ] ; then
    rm -Rf ${tbDir}
fi

# Set up cons3rt user and group
groupadd cons3rt
useradd -g cons3rt -d "/home/cons3rt" -s "/bin/bash" -c "CONS3RT User" cons3rt
usermod -a -G cons3rt cons3rt
echo "cons3rt:TMEroot!!" | chpasswd
sed -i "/^cons3rt/d" /etc/sudoers
echo "cons3rt ALL=(ALL)  ALL" >> /etc/sudoers

# Stage the TB 
mkdir -p ${tbDir}
cd ${tbDir}

# Download Template Builder
echo "Downloading Template builder: ${downloadUrl}"
curl -O ${downloadUrl}

# Mount the ISO
echo "Mounting the templace builder ISO..."
mount -o loop ${templateBuilderIso} /media

# Copy files
echo "Copying template builder to ${tbDir}..."
cp -Rf /media/* ${tbDir}/

# Unmount the ISO
echo "Unmounting the template builder ISO..."
umount /media

# Run template builder
echo "Running template builder..."
chmod +x ${tbDir}/runme.sh
${tbDir}/runme.sh
result=$?

# Cleanup
echo "Cleaning up..."
rm -Rf ${tbDir}
echo "Clearing history..."
cat /dev/null > ~/.bash_history && history -c

# Exit with the Template Builder exit code
exit ${result}
