#!/bin/bash
# Write an Ansible Inventory file
set -u
set -x 
set -o pipefail


cat << EOF > /var/lib/ansible-inventory
[all]
$HOSTS
EOF

# Execute the ansible run
### Verify ansible is installed.  Wait if not 
count=0
while [[ ! -f /usr/bin/ansible-playbook ]] ; 
do
  sleep 10 
  count=$((count +1 ))
  if [[ $count == 12 ]]; then
    echo "ansible not installed after 2 minutes"
    exit 42
  fi
done


#git clone https://github.com/jonjozwiak/heat-ansible-autoscale.git
#cd heat-ansible-autoscale

# Verify hosts are accessible 
notaccessible=true
acount=0
export ANSIBLE_HOST_KEY_CHECKING=False
while $notaccessible; do 
  ansible all --inventory /var/lib/ansible-inventory -m ping -u cloud-user
  if [[ $? == 0 ]]; then
    notaccessible=false
  else
    sleep 10
    acount=$((acount +1 ))
    if [[ $acount == 12 ]]; then
      echo "ansible cannot reach all hosts" 
      exit 3
    fi
  fi
done

# Execute Ansible Run
cd /root
export ANSIBLE_HOST_KEY_CHECKING=False
/usr/bin/ansible-playbook --inventory /var/lib/ansible-inventory apache.yml
