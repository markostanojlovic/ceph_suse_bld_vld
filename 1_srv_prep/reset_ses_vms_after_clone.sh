#!/bin/bash

if [[ -z $1 ]]
then
  echo "ERROR: ENV_CONF argument missing."; exit 1
else
  source $1
fi

set -x

# get IPs of the VMs
sudo sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config
sudo sed -i "/${NAME_BASE}/d" /etc/hosts
rm -f ~/.ssh/known_hosts
[[ -e /tmp/hostsfile ]] && sudo rm /tmp/hostsfile
touch /tmp/hostsfile

for (( i=1; i <= $VM_NUM; i++ ))
do 
  vmip=$(sudo virsh domifaddr ${NAME_BASE}${i}|grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  [[ -z $vmip ]] && exit 1
  ssh root@${vmip} "hostnamectl set-hostname --static ${NAME_BASE}${i}.${DOMAIN_NAME}" 
  echo $vmip ${NAME_BASE}${i}.${DOMAIN_NAME} ${NAME_BASE}${i} >> /tmp/hostsfile
  echo alias ${NAME_BASE}${i}="'ssh root@${NAME_BASE}${i}'" >> ~/.bashrc
done
cat /tmp/hostsfile
sudo bash -c 'cat /tmp/hostsfile >> /etc/hosts'
# removing duplicate lines 
awk '!seen[$0]++' /etc/hosts > /tmp/hosts
awk '!seen[$0]++' ~/.bashrc > /tmp/bashrc
sudo cp /tmp/hosts /etc/hosts
sudo cp /tmp/bashrc ~/.bashrc

# copy hosts file 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  scp /tmp/hostsfile root@${NAME_BASE}${i}:/tmp/
  ssh root@${NAME_BASE}${i} "cat /tmp/hostsfile >> /etc/hosts"
done

echo "Result: OK"
set +x
