#!/usr/bin/evn python
"""
Sample script to build a CONS3RT template
"""

import logging
import sys
import os

from pycons3rt.logify import Logify
from pycons3rt.awsapi.images import ImageUtil, ImageUtilError
from pycons3rt.awsapi.ec2util import EC2Util, EC2UtilError


__author__ = 'Joe Yennaco'


# Set up logger name for this module
mod_logger = Logify.get_name() + '.aws-template-bootstrap'

# For launching an instance to become a new template
my_owner_id = '017800072961'
my_ami_id = 'ami-7dbe9a18'
my_key_name = 'Ohio Template Catalog-natkeypair'
my_subnet_id = 'subnet-58d95331'
my_security_group_id = 'sg-11631378'
my_root_device_name = '/dev/sda1'
# my_root_device_name = '/dev/xvda'

# For creating or updating an AMI
my_image_name = 'Amazon Linux'
my_image_id = 'i-0c93decc9e605f262'


def get_user_data_script(os_type='Linux'):
    """Determines the path to the user-data script
    
    :param os_type: (str) Set to Linux or Windows
    :return: (str) Path to the user-data script
    """
    log = logging.getLogger(mod_logger + '.get_user_data_script')
    linux_script_file_name = 'linux-template-bootstrap.sh'
    windows_script_file_name = 'windows-template-bootstrap.sh'
    if not isinstance(os_type, basestring):
        log.error('String expected for arg os_type, found: {t}'.format(t=os_type.__class__.__name__))
        return
    os_type = os_type.lower()
    if os_type != 'linux' and os_type != 'windows':
        log.error('Incorrect os_type provided: [{t}], must be Windows or Linux'.format(t=os_type))
        return
    if os_type == 'linux':
        script_file_name = linux_script_file_name
    else:
        script_file_name = windows_script_file_name
    script_dir = sys.path[0]
    log.debug('Script execution dir: {d}'.format(d=script_dir))
    script_path = os.path.join(script_dir, script_file_name)
    if not os.path.isfile(script_path):
        log.error('User-Data script not found: {s}'.format(s=script_path))
        return
    return script_path


def build_template(os_type='Linux'):
    """Builds a CONS3RT template from an AMI ID
    
    :param os_type: (str) Linux or Windows
    :return: None
    """
    log = logging.getLogger(mod_logger + '.build_template')
    if not isinstance(os_type, basestring):
        log.error('String expected for arg os_type, found: {t}'.format(t=os_type.__class__.__name__))
        return
    os_type = os_type.lower()
    if os_type != 'linux' and os_type != 'windows':
        log.error('Incorrect os_type provided: [{t}], must be Windows or Linux'.format(t=os_type))
        return
    user_data_script = get_user_data_script(os_type)

    log.info('Attempting to launch an EC2 instance...')
    try:
        ec2 = EC2Util()
        response = ec2.launch_instance(
            ami_id=my_ami_id,
            key_name=my_key_name,
            subnet_id=my_subnet_id,
            security_group_id=my_security_group_id,
            user_data_script_path=user_data_script,
            root_device_name=my_root_device_name
        )
    except EC2UtilError:
        _, ex, trace = sys.exc_info()
        msg = '{n}: There was a problem launching an EC2 instance\n{e}'.format(n=ex.__class__.__name__, e=str(ex))
        log.error(msg)
        return
    log.info('Created instance with ID: [{i}] and info:\n{n}'.format(
        i=response['InstanceId'], n=response['InstanceInfo']))


def create_new_cons3rt_template():
    """Creates a new CONS3RT template using the provided instance ID and image name
    
    :return: None
    """
    log = logging.getLogger(mod_logger + '.create_new_cons3rt_template')
    img = ImageUtil(owner_id=my_owner_id)
    try:
        img.create_cons3rt_template(instance_id=my_image_id, name=my_image_name)
    except ImageUtilError:
        _, ex, trace = sys.exc_info()
        msg = '{n}: There was a problem creating a new image\n{e}'.format(n=ex.__class__.__name__, e=str(ex))
        log.error(msg)
        return


def main():
    """Sample usage for this python module

    :return: None
    """
    log = logging.getLogger(mod_logger + '.main')
    log.info('Running Main!!!')
    build_template(os_type='linux')
    # create_new_cons3rt_template()


if __name__ == '__main__':
    main()
