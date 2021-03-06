#!/bin/bash
###############################################################################
# This script installs pulls down the ansible playbooks needed
###############################################################################

# TODO: Change to git 
set -eu
set -x 
set -o pipefail


cat << EOF > /root/apache.yml
# apache.yml
---
- hosts: all 
  remote_user: cloud-user
  sudo: yes
  tasks:
    - name: Install Apache
      yum: name=httpd state=present

    - name: Create index.html page
      template: src=index.html.j2 dest=/var/www/html/index.html

    - name: Start and Enable Apache
      service: name=httpd state=running enabled=yes
EOF
 
echo "You are on {{ ansible_nodename }}" > /root/index.html.j2
