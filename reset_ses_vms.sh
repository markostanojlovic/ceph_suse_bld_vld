#!/bin/bash
# Reseting the VMs for the test deployment of Ceph/SES cluster

# What are the requirements of the clone image:
# - grub2 settings: /etc/default/grub; grub2-mkconfig -o /boot/grub2/grub.cfg 
#     - console=ttyS0
#     - GRUB_TIMEOUT=2
# - ntpd started and configured for : cz.pool.ntp.org
# - repos are configured and image is patched to latest updates 
# - apparmor disabled
# - IPv6 disabled 
# - Suse Firewall disabled 
# - ssh hey copied in .ssh/authorized_keys 

# Most important vars to setup:
# - number of VMs
# - VM template image
# - libvirt pool for storing images 

sript_start_time=$(date +%s)
set -x
TMPL_IMG=sles12sp3_clone_img.qcow2
TMPL_VM_NAME=${TMPL_IMG%.qcow2}
POOL="/VM"
VM_NUM=5
NAME_BASE=sesqa
DOMAIN_NAME=qatest

# clean old 
# TODO: check if they are running or existing  
for (( i=1; i <= $VM_NUM; i++ ))
do 
  virsh destroy ${NAME_BASE}${i}
  virsh undefine ${NAME_BASE}${i}
done
rm -rf ${POOL}/${NAME_BASE}*

# clone
for (( i=1; i <= $VM_NUM; i++ ))
do 
  virt-clone --original $TMPL_VM_NAME --name ${NAME_BASE}${i} --file=${POOL}/${NAME_BASE}${i}.qcow2
  # add disks 
  for j in c d e f
  do
    DISK="${POOL}/${NAME_BASE}-osd${i}-${j}"
    qemu-img create -f raw $DISK 30G
    virsh attach-disk ${NAME_BASE}${i} $DISK vd${j} --config 
  done
done 

# start 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  virsh start ${NAME_BASE}${i}
done 

set +x
# calculating script execution duration
sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes (clone operation): " $script_runtime

###############################
sleep 45
###############################

set -ex 
# get IPs of the VMs
sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config
sed -i "/${NAME_BASE}/d" /etc/hosts
sed -i "/${NAME_BASE}/d" /root/.ssh/known_hosts
> /tmp/hostsfile
for (( i=1; i <= $VM_NUM; i++ ))
do 
  vmip=$(virsh domifaddr ${NAME_BASE}${i}|grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  echo $vmip ${NAME_BASE}${i}
  ssh root@${vmip} "hostnamectl set-hostname --static ${NAME_BASE}${i}.${DOMAIN_NAME}" 
  #ssh root@${vmip} "SUSEConnect -p ses/5/x86_64 -r aa65051fefaa5750 -e mstanojlovic@suse.com"
  echo $vmip ${NAME_BASE}${i}.${DOMAIN_NAME} ${NAME_BASE}${i} >> /tmp/hostsfile
done
cat /tmp/hostsfile
cat /tmp/hostsfile >> /etc/hosts

# copy hosts file 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  scp /tmp/hostsfile root@${NAME_BASE}${i}:/tmp/
  ssh ${NAME_BASE}${i} "cat /tmp/hostsfile >> /etc/hosts"
done

# configure salt master
cat <<EOF > /tmp/configure_salt_master.sh 
set -ex
SALT_MASTER_IP=\$(ip a s dev eth0|grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"|grep -v 255)
zypper in -y deepsea
sed -i "/#interface: 0.0.0.0/c\interface: \${SALT_MASTER_IP}" /etc/salt/master
sed -i "/#timeout: 5/c\timeout: 25" /etc/salt/master
sed -i "/#master: salt/c\master: ${NAME_BASE}1" /etc/salt/minion
systemctl enable salt-minion.service;systemctl start salt-minion.service;systemctl status salt-minion.service
systemctl enable salt-master.service;systemctl start salt-master.service;systemctl status salt-master.service
EOF

scp /tmp/configure_salt_master.sh root@${NAME_BASE}1:/tmp/
ssh root@${NAME_BASE}1 "chmod +x /tmp/configure_salt_master.sh"
ssh root@${NAME_BASE}1 "source /tmp/configure_salt_master.sh"

# configure salt minions 
cat <<EOF > /tmp/configure_salt_minion.sh
set -ex 
MASTER=${NAME_BASE}1
zypper in -y salt-minion
sed -i "/#master: salt/c\master: \$MASTER" /etc/salt/minion
systemctl enable salt-minion.service;systemctl start salt-minion.service
sed -i "/server cz.pool.ntp.org iburst/c\server \$MASTER iburst" /etc/ntp.conf
systemctl stop ntpd
ntpdate -bs cz.pool.ntp.org
systemctl start ntpd
sntp -S -c \$MASTER || echo
EOF

for (( i=2; i <= $VM_NUM; i++ ))
do
  scp /tmp/configure_salt_minion.sh root@${NAME_BASE}${i}:/tmp/
  ssh root@${NAME_BASE}${i} "chmod +x /tmp/configure_salt_minion.sh"
  ssh root@${NAME_BASE}${i} "nohup /tmp/configure_salt_minion.sh >/tmp/minion.log 2>&1 &"
done 

# waiting for salt-minions to be installed 
sleep 120

# accept salt keys 
ssh root@${NAME_BASE}1 "salt-key --accept-all -y;sleep 5;salt \* test.ping"

set +ex
# calculating script execution duration
sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes : " $script_runtime

