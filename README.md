Heat Auto-scaling with Ansible 
==============================

These heat templates will demonstrate using Ansible within Heat when implementing auto-scaling.  Ansible will run from a central host and handle the configuration of nodes that are scaled while heat will manage the actual scaling and OpenStack-related components.  

For the actual application this will deploy a simple Apache webserver with an index page indicating which host you are running on

Don't forget to change /etc/ceilometer/pipeline.yaml to have CPU events align with the alarm spec (60 seconds) for auto-scaling: 
```
    - name: cpu_source
      interval: 60
      meters:
          - "cpu"
      sinks:
          - cpu_sink

systemctl restart openstack-ceilometer-compute
```

Create the heat stack.  Note you may need to update some of the default parameters in autoscale.yaml to match your environment.  

```
heat stack-create -f autoscale.yaml testscale
```

NOTE: You can ignore the initial haproxy backend messages saying no server is available.  This is because HAProxy starts prior to the Nova instances being available

At this point you can watch the heat stack to completion and then verify things are working.  We will verify just by using curl and seeing both web servers respond.  

```
heat stack-list 
heat resource-list -n 5 testscale | grep IN_PROGRESS
```

Eventually (maybe 5 minutes?) the stack-list should show CREATE_COMPLETED

```
heat output-list
WEBIP=$(heat output-show testscale web_url | sed 's/"//g')
curl $WEBIP
```

Assuming that both web servers are responding, we can now manually scale up the environment.  

```
heat stack-update -f autoscale.yaml -P node_count=4 testscale
```

Test as before and once the update is complete you should see 4 web servers responding.  You can scale back to 2 nodes and it will reduce back to normal.

NOTE: At this point auto-scaling is not implemented.  There is a timing issue that needs to be addressed (ensuring that the auto-scale does not interrupt another event


Troubleshooting: 

To check a failed software deployment on the ansible host:
```
heat resource-list -n 5 testscale 
ansible_host_uuid=$(heat resource-list testscale | grep ansible_host | awk '{print $4}')
heat resource-show $ansible_host_uuid deploy_ansible_inventory
```

Chances are it's not going to tell much so connect to the ansible host to troubleshoot.  Note I don't have a public IP so connect through the namespace.  For example: 
``` 
# Find your Ansible IP
nova list 

# Find your DHCP namespace via neutron net UUID
neutron net-list  
ip netns 
ip netns exec qdhcp-<net-uuid> ssh -i /root/adminkey.pem cloud-user@<ansible ip>

# On ansible host: 
sudo su - 
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log
cat /var/log/messages

# Check heat scripts in /var/lib/heat-config/heat-config-script.  You can execute these to test if they work.  

# Check /var/lib/ansible-inventory and ensure it's correct
```

