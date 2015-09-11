#!/bin/bash
###############################################################################
# This script installs and configures the required heat tools which are used
# to monitor metadata changes and apply config based on the updates
###############################################################################

set -eu
set -x 
set -o pipefail

yum -y install git

# Setup CentOS Cloud Repo & Install software-config agent
yum -y install http://mirror.centos.org/centos/7/cloud/x86_64/openstack-kilo/centos-release-openstack-kilo-2.el7.noarch.rpm
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/CentOS-OpenStack-kilo.repo
yum -y --enablerepo=centos-openstack-kilo install os-apply-config os-collect-config os-refresh-config dib-utils python-heatclient python-zaqarclient

# Configure software-config agent
cd /tmp
git clone https://github.com/openstack/heat-templates.git

# os-apply-config templates directory
oac_templates=/usr/libexec/os-apply-config/templates
mkdir -p $oac_templates/etc


# template for building os-collect-config.conf for polling heat
cat <<EOF >$oac_templates/etc/os-collect-config.conf
[DEFAULT]
{{^os-collect-config.command}}
command = os-refresh-config
{{/os-collect-config.command}}
{{#os-collect-config}}
{{#command}}
command = {{command}}
{{/command}}
{{#polling_interval}}
polling_interval = {{polling_interval}}
{{/polling_interval}}
{{#cachedir}}
cachedir = {{cachedir}}
{{/cachedir}}
{{#collectors}}
collectors = {{collectors}}
{{/collectors}}
{{#cfn}}
[cfn]
{{#metadata_url}}
metadata_url = {{metadata_url}}
{{/metadata_url}}
stack_name = {{stack_name}}
secret_access_key = {{secret_access_key}}
access_key_id = {{access_key_id}}
path = {{path}}
{{/cfn}}
{{#heat}}
[heat]
auth_url = {{auth_url}}
user_id = {{user_id}}
password = {{password}}
project_id = {{project_id}}
stack_id = {{stack_id}}
resource_name = {{resource_name}}
{{/heat}}
{{#request}}
[request]
{{#metadata_url}}
metadata_url = {{metadata_url}}
{{/metadata_url}}
{{/request}}
{{/os-collect-config}}
EOF
mkdir -p $oac_templates/var/run/heat-config

# template for writing heat deployments data to a file
echo "{{deployments}}" > $oac_templates/var/run/heat-config/heat-config

# os-refresh-config scripts directory
orc_scripts=/usr/libexec/os-refresh-config
# Create directories
for d in pre-configure.d configure.d migration.d post-configure.d; do
    install -m 0755 -o root -g root -d $orc_scripts/$d
done

# os-refresh-config script for running os-apply-config
cat <<EOF >$orc_scripts/configure.d/20-os-apply-config
#!/bin/bash
set -ue
exec os-apply-config
EOF
chmod 700 $orc_scripts/configure.d/20-os-apply-config

# os-refresh-config script for running heat config hooks
#cat <<EOF >$orc_scripts/configure.d/55-heat-config
#$heat_config_script
#EOF
cp /tmp/heat-templates/hot/software-config/elements/heat-config/os-refresh-config/configure.d/55-heat-config $orc_scripts/configure.d/55-heat-config
chmod 700 $orc_scripts/configure.d/55-heat-config

# config hook for shell scripts
hooks_dir=/var/lib/heat-config/hooks
mkdir -p $hooks_dir

# install hook for configuring with shell scripts
#cat <<EOF >$hooks_dir/script
#$hook_script
#EOF
cp /tmp/heat-templates/hot/software-config/elements/heat-config-script/install.d/hook-script.py $hooks_dir/script
chmod 755 $hooks_dir/script

# install heat-config-notify command
#cat <<EOF >/usr/bin/heat-config-notify
#$heat_config_notify
#EOF
cp /tmp/heat-templates/hot/software-config/elements/heat-config/bin/heat-config-notify /usr/bin/heat-config-notify
chmod 755 /usr/bin/heat-config-notify

# run once to write out /etc/os-collect-config.conf
os-collect-config --one-time --debug
cat /etc/os-collect-config.conf

# run again to poll for deployments and run hooks
os-collect-config --one-time --debug

# Start os-collect-config
systemctl enable os-collect-config
systemctl start --no-block os-collect-config


## /var/lib/heat-config/hooks
   #-> File called puppet
  #-> File called scripts
  # 755 ... owned by root
  #Basically they're just the .py file copied and renamed.  
  # Create a directory /var/lib/heat-config/heat-config-puppet or heat-config-script.  These are just blank for holding the eventual scripts... 
## /usr/local/bin/heat-config-notify
   ## Python script - This uses the heat and keystone python clients... just fyi ... 

### Example /etc/os-collect-config.conf
#[DEFAULT]
#command = os-refresh-config
#
#[cfn]
#metadata_url = http://ip:8000/v1/
#stack_name = overcloud-controller-blahblah
#secret_access_key = e5ff4722d......
#access_key_id = 4a95008bdf604.....
#path = Controller.Metadata

# Note - data collected from os-collect-config is stored in /var/lib/os-collect-config

