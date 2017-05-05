#!/usr/bin/env bash

IP=$1
KEY=$2
OS=$3

# files should be in same directory as this script
UBUNTU_FILES="ibm-java-sdk-8.0-4.2-ppc64le-archive.bin templatebuilder.jar cons3rt-agent.jar nvidia-driver-local-repo-ubuntu1604_375.51-1_ppc64el.deb"

function main {

    options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    if [ "${OS}" == "ubuntu" ]; then
        createUbuntuScript
        FILES="${UBUNTU_FILES}"
        REMOTE_USER="ubuntu"
        REMOTE_DIR="/home/ubuntu"
    else
        echo "Not done yet"
    fi

    scp ${options} -r -i ${KEY} ${FILES} ${REMOTE_USER}@${IP}:${REMOTE_DIR}
    ssh ${options} -i ${KEY} ${REMOTE_USER}@${IP} bash < script.sh

    rm -f script.sh

}

function createUbuntuScript {

cat << 'UBUNTU_EOF' > script.sh
#!/bin/bash

# TODO
# - add interfaces via cloud-init? currently just add interface files at the end
# - remove old cloud-init?

function main {

    cd $HOME
    cat /dev/null > $HOME/.bash_history
    unset HISTFILE

    installPackages
    fixes
    updateOs
    installCloudInit
    configCloudInit
    configCloudDrive
    installJava
    installCons3rtAgent
    createBootstrapper
    buildJsvc
    installNvidia
    #createUser
    #setupDesktop
    configNetwork
    finalCleanup

}

function installPackages {

    sudo apt -y install ssh

}

function fixes {

    # fix annoying "sudo: unable to resolve host" warning
    sudo sed -i "$ a 127.0.0.1 $HOSTNAME" /etc/hosts > /dev/null 2>&1

}

function updateOs {

    sudo rm -rf /var/lib/apt/lists/*
    sudo /usr/share/debconf/fix_db.pl
    sudo apt-get -qq update
    sudo apt-get -qq upgrade

}

function installCloudInit {

    # build, install, and cleanup cloud-init
    sudo apt-get -y install git python3-setuptools
    git clone https://git.launchpad.net/cloud-init
    cd cloud-init/
    sudo python3 setup.py build
    sudo python3 setup.py install --init-system systemd
    cd ..
    sudo rm -rf cloud-init/
    sudo umount /var/lib/cloud/data
    sudo rm -rf /var/lib/cloud

}

function configCloudInit {

    # configure cloud-init

    CONFIG='/etc/cloud/cloud.cfg'
    sudo sed -i 's/preserve_hostname:.*$/preserve_hostname: true/' ${CONFIG}
    sudo sed -i 's/ name:.*$/ name: cons3rt/' ${CONFIG}
    sudo sed -i "/ name: cons3rt/a\ \ \ \ \ plain_text_passwd: \'TMEroot\!\!\'" ${CONFIG}
    sudo sed -i 's/ lock_passwd:.*$/ lock_passwd: false/'  ${CONFIG}
    sudo sed -i 's/ gecos:.*$/ gecos: CONS3RT User/'  ${CONFIG}
    sudo sed -i 's/datasource_list:.*$/datasource_list: [ ConfigDrive ]/' ${CONFIG}.d/90_dpkg.cfg

}

function configCloudDrive {

    # fix config drive

    datasourceconfigdrive=$(sudo find /usr/local -name DataSourceConfigDrive.py)
    sudo sed -i 's,/config-drive,/var/lib/cloud/data,' ${datasourceconfigdrive}
    sudo python3 -m compileall ${datasourceconfigdrive}

}

function installJava {

    # install java and cleanup

    # curl -O http://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/8.0.4.2/linux/ppc64le/ibm-java-sdk-8.0-4.2-ppc64le-archive.bin
    sudo mkdir -p /opt/cons3rt-agent/tools
    sudo sh $HOME/ibm-java-sdk-8.0-4.2-ppc64le-archive.bin -i silent -DLICENSE_ACCEPTED=TRUE -DUSER_INSTALL_DIR=/opt/cons3rt-agent/tools
    sudo rm -f $HOME/ibm-java-sdk-8.0-4.2-ppc64le-archive.bin

}

function installCons3rtAgent {

    # install cons3rt agent

    sudo echo 'CLOUD_TYPE=2' > $HOME/cons3rt.openstack
    sudo /opt/cons3rt-agent/tools/jre/bin/java -jar $HOME/templatebuilder.jar -options $HOME/cons3rt.openstack
    sudo rm $HOME/templatebuilder.jar
    sudo rm -rf $HOME/tools
    sudo rm -f $HOME/cons3rt.openstack
    sudo mv cons3rt-agent.jar /root

}

function buildJsvc {

    # compile jsvc and cleanup

    sudo apt-get -y install autoconf make gcc
    curl -O http://apache.cs.utah.edu//commons/daemon/source/commons-daemon-1.0.15-src.tar.gz
    tar xvf commons-daemon-1.0.15-src.tar.gz
    cd commons-daemon-1.0.15-src/src/native/unix/
    sudo sh support/buildconf.sh
    git clone http://git.savannah.gnu.org/r/config.git
    sudo mv -f config/config.guess support/config.guess
    sudo rm -rf config
    sudo sed -i 's/powerpc/powerpc\*/' configure
    sudo ./configure --with-java=/opt/cons3rt-agent/tools/
    sudo make
    sudo mv jsvc /root/
    cd $HOME
    sudo rm -rf commons-daemon-1.0.15-src*

}

function installNvidia {

    # install nvidia drivers

    # curl -O http://us.download.nvidia.com/tesla/375.51/nvidia-driver-local-repo-ubuntu1604_375.51-1_ppc64el.deb
    sudo dpkg -i $HOME/nvidia-driver-local-repo-ubuntu1604_375.51-1_ppc64el.deb
    sudo apt-get update
    sudo apt-get -y install cuda-drivers
    sudo rm -f $HOME/nvidia-driver-local-repo-ubuntu1604_375.51-1_ppc64el.deb

}

function configNetwork {

    # configure network interfaces

    echo $'auto eth0\niface eth0 inet dhcp' | sudo tee /etc/network/interfaces.d/ifcfg-eth0.cfg > /dev/null
    echo $'auto eth1\niface eth1 inet dhcp' | sudo tee /etc/network/interfaces.d/ifcfg-eth1.cfg > /dev/null

}

function createUser {

    USER='cons3rt'
    PASSWORD='TMEroot!!'
    sudo useradd ${USER}
	echo "${USER}:${PASSWORD}" | sudo chpasswd

}

function setupDesktop {

    sudo apt-get -y install tightvncserver xfce4 xfce4-goodies xvfb

    cat << 'EOF' > x11vnc.service
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
#User=cons3rt
#PAMName=login
ExecStart=/usr/bin/x11vnc -create -forever -bg -env FD_TAG=Desktop -env FD_SESS=xfce -autoport 5902 -rfbauth /etc/x11vnc.pass -o /var/log/x11vnc.log
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo mv -f x11vnc.service /etc/systemd/system/

#    sudo chmod +x /home/cons3rt/.vnc/xstartup
#    sudo chown -R cons3rt:cons3rt /home/cons3rt/.vnc
#    sudo chmod +x /home/cons3rt/.vnc/xstartup
#    sudo chmod 600 /home/cons3rt/.vnc/passwd

    sudo systemctl daemon-reload
#    sudo systemctl enable vncserver@2.service
    #sudo vncserver -kill :1
#    sudo systemctl start vncserver@2
    #sudo systemctl status vncserver@2

}

function finalCleanup {

    # final cleanup

    umount /media
    rm -rf /media/*
    #rm -- "$0"

}

function createBootstrapper {

cat << 'EOF' > cons3rtAgentInstaller
#!/bin/bash
# $Id$
#
# cons3rtAgentInstaller    This shell script installs the latest cons3rt agent and chkconfigs it off
#
####
# This script installs and executes the CONS3RT Agent on Linux systems
# Last Update 20140407 tvs
####
# chkconfig: 2345 99 09
# description: CONS3RT Agent Installer process

### BEGIN INIT INFO
# Provides:          cons3rtagentInstaller
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start cons3rtagentInstaller at boot time
# Description:       Enables the service cons3rtagentInstaller
### END INIT INFO

# Command line operations
OP=${1}

####
# Local variables to be modified per environment

# This is the installed location of the CONS3RT agent - this must
# be coordinated with the FAP agent service script
CONS3RT_AGENT_HOME=/opt/cons3rt-agent


####
# Variables which should not be modified unless you really know what you're doing
DATE=`date +%y%m%d`
PROG="cons3rtAgentInstaller"
CONS3RT_AGENT_NAME="cons3rtagent"
AGENT_LOG=/var/log/${PROG}.log
CONS3RT_RUN_URI_FILE=${CONS3RT_AGENT_HOME}/tools/webdav.cfg
CONS3RT_AGENT_INSTALL_DIR=/opt
DISTRO="unknown"
SYSTEMD=0
####

export CONS3RT_AGENT_HOME


function run_and_check_status {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "error executing $1"
        exit 1
    fi
    return $status
}


copy_agent() {
    echo "Preparing CONS3RT Agent directory"

    if [ ! -d ${CONS3RT_AGENT_HOME} ]; then
       mkdir ${CONS3RT_AGENT_HOME}
    fi

    if [ ! -d ${CONS3RT_AGENT_HOME}/log ]; then
       mkdir ${CONS3RT_AGENT_HOME}/log
    fi

    chown -R root:root ${CONS3RT_AGENT_HOME}

    # Run bootstrapper

    # Path to bootstrap file to use
    CONS3RT_AGENT_BOOTSTRAP=${CONS3RT_AGENT_HOME}/bootstrap-cons3rt-agent.jar

    # Specify any optional params to java, like -Xmx, etc
    CONS3RT_AGENT_JAVA_PARAMS=

    MACHINE_TYPE=`uname -m`

    if [[ ${MACHINE_TYPE} =~ .*armv.* ]] ; then
    # arm6/7 stuff here
        echo "ARM CPU detected, adding parameter -Xmx128m to JRE runtime" >> ${AGENT_LOG} 2>&1
        CONS3RT_AGENT_JAVA_PARAMS="${CONS3RT_AGENT_JAVA_PARAMS} -Xmx128m"
    fi

    # Parameters to be passed to CONS3RT Agent bootstraper. Uncomment the line below to enable bootstrap debug info to /var/log/cons3rtAgentInstaller.log
    # CONS3RT_AGENT_BOOTSTRAP_DEBUG=-debug
    CONS3RT_AGENT_BOOTSTRAP_PARAMS="-localInstallDir ${CONS3RT_AGENT_INSTALL_DIR} -runDirUriFile ${CONS3RT_RUN_URI_FILE} ${CONS3RT_AGENT_BOOTSTRAP_DEBUG}"

    echo "Installing CONS3RT Agent"
    run_and_check_status ${CONS3RT_AGENT_HOME}/tools/jre/bin/java ${CONS3RT_AGENT_JAVA_PARAMS} -jar ${CONS3RT_AGENT_BOOTSTRAP} ${CONS3RT_AGENT_BOOTSTRAP_PARAMS}
    run_and_check_status mv -f /root/cons3rt-agent.jar ${CONS3RT_AGENT_HOME}/
    run_and_check_status mkdir -p ${CONS3RT_AGENT_HOME}/tools/commons-daemon
    run_and_check_status mv -f /root/jsvc ${CONS3RT_AGENT_HOME}/tools/commons-daemon/

    echo "Installing CONS3RT Agent service script"
    if [ -e /etc/init.d/${CONS3RT_AGENT_NAME} ]
    then
        echo "Saving previous CONS3RT Agent service script"
        if [ ${SYSTEMD} = 1 ]
            then
                run_and_check_status systemctl disable ${CONS3RT_AGENT_NAME}.service
            else

            if [ ${DISTRO} = redhat ]
            then
              run_and_check_status /sbin/chkconfig --del ${CONS3RT_AGENT_NAME}
            elif [ ${DISTRO} = debian ]
            then
              run_and_check_status /usr/sbin/update-rc.d -f ${CONS3RT_AGENT_NAME} remove
            fi
            mv /etc/init.d/${CONS3RT_AGENT_NAME} ${CONS3RT_AGENT_HOME}/${CONS3RT_AGENT_NAME}.${DATE}
        fi
    fi

    cp ${CONS3RT_AGENT_HOME}/scripts/service-scripts/cons3rt_agent_service_linux.sh /etc/init.d/${CONS3RT_AGENT_NAME}

    if [ ${SYSTEMD} = 1 ]
    then
        cp ${CONS3RT_AGENT_HOME}/scripts/service-scripts/cons3rtagent.service /lib/systemd/system/
    fi

    chmod +x /etc/init.d/${CONS3RT_AGENT_NAME}
}

enable_agent() {
    echo "Enabling CONS3RT Agent service script"

    if [ ${SYSTEMD} = 1 ]
    then
        run_and_check_status systemctl enable ${CONS3RT_AGENT_NAME}.service
    else
        if [ ${DISTRO} = redhat ]
        then
            run_and_check_status /sbin/chkconfig --add ${CONS3RT_AGENT_NAME}
            run_and_check_status /sbin/chkconfig ${CONS3RT_AGENT_NAME} on
        elif [ ${DISTRO} = debian ]
        then
            run_and_check_status /usr/sbin/update-rc.d ${CONS3RT_AGENT_NAME} defaults
    fi
   fi
}

# Only needed on Redhat derivatives
disable_installer() {
    echo "Disabling CONS3RT Agent installer script"

 if [ ${SYSTEMD} = 1 ]
    then
        run_and_check_status systemctl disable ${PROG}.service
    else
        if [ ${DISTRO} = redhat ]
            then
              run_and_check_status /sbin/chkconfig ${PROG} off
        fi
    fi

}

start_agent() {
    echo "Starting CONS3RT Agent"
    if [ ${SYSTEMD} = 1 ]
    then
        run_and_check_status systemctl start ${CONS3RT_AGENT_NAME}.service
   else
        run_and_check_status service ${CONS3RT_AGENT_NAME} start
   fi

}

##########################################################################################

start() {
    echo -n $"Starting ${PROG}: "

    # This is the URI location of the cons3rt agent on the cons3rt server
    # CONS3RT_RUN_URI="webdavs://$WEBDAVS_USER:$WEBDAVS_PASS@${CONS3RT_SERVER}:8443"
    check_distro >> ${AGENT_LOG} 2>&1

    check_systemd >> ${AGENT_LOG} 2>&1

    copy_agent >> ${AGENT_LOG} 2>&1

    enable_agent >> ${AGENT_LOG} 2>&1

    disable_installer >> ${AGENT_LOG} 2>&1

    start_agent >> ${AGENT_LOG} 2>&1

    echo "${PROG} complete: "
}

stop() {
    echo "Stop not implemented for ${PROG}: "
}

check_distro() {
    if [ -e /sbin/chkconfig ]
    then
        echo "Red Hat distribution found"
        DISTRO=redhat
    elif [ -e /usr/sbin/update-rc.d ]
    then
        echo "Debian distribution found"
        DISTRO=debian
    fi
}

check_systemd() {
    which systemctl

    if [ $? = 0 ]
    then
        SYSTEMD=1
        echo "SYSTEMD found"
    fi
}

case "${OP}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        echo "Usage: $0 {start}"
        ;;
esac
EOF

    sudo chmod +x cons3rtAgentInstaller
    sudo chown root:root /etc/init.d/cons3rtAgentInstaller
    sudo mv -f cons3rtAgentInstaller /etc/init.d/

}

main
sudo reboot
#echo "Please reboot!"
UBUNTU_EOF

}

main