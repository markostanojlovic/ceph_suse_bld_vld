#!/bin/bash
# Reseting the VMs for the test deployment of Ceph/SES4 cluster 
# by using *** ceph-deploy ***

# What are the requirements of the clone image SLES12SP2 :
# - grub2 settings: /etc/default/grub; grub2-mkconfig -o /boot/grub2/grub.cfg 
#     - console=ttyS0
#     - GRUB_TIMEOUT=2
# - ntpd started and configured for : 
# - repos are configured and image is patched to latest updates ** SLES12SP2 & SES4 **
# - apparmor disabled
# - set via yast: *** set hostname via DHCP to NO ***
# - IPv6 disabled 
# - Suse Firewall disabled 
# - User cephadm created :
#     - useradd -m cephadm && passwd cephadm # linux
#     - echo "cephadm ALL = (root) NOPASSWD:ALL" >> /etc/sudoers
#     - ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
# - ssh hey copied in .ssh/authorized_keys 
# - ssh config 
#     - sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config
# - install ceph and ceph-deploy: zypper in -y ceph ceph-deploy

# Most important vars to setup:
# - number of VMs
# - VM template image
# - libvirt pool for storing images 

# [ EXPECTED RUNTIME : 12 min ] 

sript_start_time=$(date +%s)
set -x
TMPL_IMG=sles12sp2_clone.qcow2
TMPL_VM_NAME=${TMPL_IMG%.qcow2}
POOL="/VM-disk-b"
VM_NUM=5
NAME_BASE=ses4qa
DOMAIN_NAME=qatest

# clean old 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  virsh destroy ${NAME_BASE}${i} || echo Error: VM ${NAME_BASE}${i} not running
  virsh undefine ${NAME_BASE}${i} || echo Error: VM ${NAME_BASE}${i} not defined
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

# exchanging keys 
## getting the cephadm key 
scp root@${NAME_BASE}1:/home/cephadm/.ssh/id_rsa.pub /tmp/master_node_rsa.pub
## copy public key to authorized_keys file 
for (( i=2; i <= $VM_NUM; i++ ))
do 
  scp /tmp/master_node_rsa.pub root@${NAME_BASE}${i}:/tmp/
  ssh ${NAME_BASE}${i} "cat /tmp/master_node_rsa.pub >> /home/cephadm/.ssh/authorized_keys"
done

# deploy SES 
cat <<EOF > /tmp/deploy_SES.sh
function _wait_health_ok {
  timer_checkpoint=\$(date +%s)
  timer=300
  while sleep 5 
  do
    dif=\$((( \$(date +%s)-\$timer_checkpoint )))
    if [[ \$dif -le \$timer ]]
    then 
      if [[ \$(ceph health|head -n 1) -eq "HEALTH_OK" ]]
        then 
        echo "HEALTH_OK"
        break 
      fi
    else
      echo "Error: Ceph HEALTH TIMEOUT!"
      break 
    fi
  done
}

set -x
# installs ceph on each node
ceph-deploy install ses4qa1 ses4qa2 ses4qa3 ses4qa4 ses4qa5
# configures mon nodes
ceph-deploy new ses4qa1 ses4qa2 ses4qa3
# start mon service
ceph-deploy mon create-initial
# configure admin node by creating keyring file 
ceph-deploy admin ses4qa1 ses4qa2 ses4qa3 ses4qa4 ses4qa5
# configure OSDs
ceph-deploy osd prepare \
ses4qa2:vdb ses4qa2:vdc ses4qa2:vdd ses4qa2:vde \
ses4qa3:vdb ses4qa3:vdc ses4qa3:vdd ses4qa3:vde \
ses4qa4:vdb ses4qa4:vdc ses4qa4:vdd ses4qa4:vde \
ses4qa5:vdb ses4qa5:vdc ses4qa5:vdd ses4qa5:vde


# create few pools to avoid "too few PGs per OSD"
sudo ceph osd pool create iscsi 128 128

# wait until cluster is stable
_wait_health_ok

# DEPLOY RGW 
ceph-deploy install --rgw ses4qa2
ceph-deploy --overwrite-conf rgw  create ses4qa2
## verify:
rgw_service_status=\$(ssh ses4qa2 "systemctl status ceph-radosgw@rgw.ses4qa2.service"|grep Active)
echo \$rgw_service_status|grep "active (running)" || echo "Error: RGW service KO."
curl ses4qa2:7480

set +x
EOF

scp /tmp/deploy_SES.sh root@${NAME_BASE}1:/tmp/
ssh root@${NAME_BASE}1 "chmod +x /tmp/deploy_SES.sh"
ssh root@${NAME_BASE}1 "su - cephadm -c 'source /tmp/deploy_SES.sh'"

# DEPLOY OPEN-ATTIC @5th node 
cat <<EOF > /tmp/deploy_openAttic.sh
set -x
sudo zypper in -y openattic
sudo ceph auth add client.openattic mon 'allow *' osd 'allow *'
sudo ceph auth get client.openattic -o /etc/ceph/ceph.client.openattic.keyring
sudo chmod 660 /etc/ceph/ceph.client.openattic.keyring
sudo chown openattic:openattic /etc/ceph/ceph.client.openattic.keyring
sudo oaconfig install
## verify:
systemctl status openattic-systemd.service|grep Active
curl ses4qa5:80
set +x
EOF

scp /tmp/deploy_openAttic.sh root@${NAME_BASE}5:/tmp/
ssh root@${NAME_BASE}5 "chmod +x /tmp/deploy_openAttic.sh"
ssh root@${NAME_BASE}5 "su - cephadm -c 'source /tmp/deploy_openAttic.sh'"

ses4qa3_ip_addr=$(cat /etc/hosts|grep ses4qa3|awk '{print $1}')

# DEPLOY IGW @3rd node 
cat <<EOF > /tmp/lrbd.conf
{
    "auth": [
        {
            "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
            "authentication": "none"
        }
    ],
    "targets": [
        {
            "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
            "hosts": [
                {
                    "host": "ses4qa3.qatest",
                    "portal": "east"
                }
            ]
        }
    ],
    "portals": [
        {
            "name": "east",
            "addresses": [
                "$ses4qa3_ip_addr"
            ]
        }
    ],
    "pools": [
        {
            "pool": "iscsi",
            "gateways": [
                {
                    "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
                    "tpg": [
                        {
                            "image": "demo"
                        }
                    ]
                }
            ]
        }
    ]
    }
EOF

cat <<EOF > /tmp/deploy_IGW.sh
set -x
sudo rbd -p iscsi create --size=2G demo
sudo rbd -p iscsi ls 
sudo zypper in -y -t pattern ceph_iscsi 
sudo systemctl enable lrbd
sudo lrbd -f /tmp/lrbd.conf 
sudo systemctl start lrbd 
sudo systemctl status lrbd -l 
sudo targetcli ls 
set +x
EOF

scp /tmp/lrbd.conf root@${NAME_BASE}3:/tmp/
scp /tmp/deploy_IGW.sh root@${NAME_BASE}3:/tmp/
ssh root@${NAME_BASE}3 "chmod +x /tmp/deploy_IGW.sh"
ssh root@${NAME_BASE}3 "su - cephadm -c 'source /tmp/deploy_IGW.sh'"

set +ex
# calculating script execution duration
sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes : " $script_runtime

