#!/bin/bash
# NOTES: 
# 	- only 3 mons: nodes 1,2,3 
#	- rgw deployed at node 2 

if [[ -z $1 ]]
then
  echo "ERROR: argument missing. USAGE: ./1_srv_prep/reset_ses_vms.sh cfg/maiax86_64.cfg"
  exit 1
else
  source $1
fi

set -x

NODES=''
for (( i=1; i <= $VM_NUM; i++ ))
do
  ssh root@${NAME_BASE}${i} <<EOSSH
useradd -m cephadm
echo 'cephadm:qa.adm-01'|chpasswd
echo "cephadm ALL = (root) NOPASSWD:ALL" >> /etc/sudoers
sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config
su - cephadm
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
EOSSH
  NODES="${NAME_BASE}${i} $NODES"
done

OSD_LIST=''
ADMIN_NODE_SSH=$(ssh root@$MASTER cat /home/cephadm/.ssh/id_rsa.pub)
for (( i=2; i <= $VM_NUM; i++ ))
do
  ssh root@${NAME_BASE}${i} "echo $ADMIN_NODE_SSH|tee -a /home/cephadm/.ssh/authorized_keys"
  OSD_LIST="${NAME_BASE}${i}:vda ${NAME_BASE}${i}:vdb ${NAME_BASE}${i}:vdc ${NAME_BASE}${i}:vdd $OSD_LIST"
done

ssh root@$MASTER "cat /root/.ssh/authorized_keys|tee -a /home/cephadm/.ssh/authorized_keys"

ssh cephadm@$MASTER <<EOSSH
set -x
sudo zypper in -y ceph ceph-deploy
ceph-deploy install $NODES
ceph-deploy new ${NAME_BASE}1 ${NAME_BASE}2 ${NAME_BASE}3
ceph-deploy mon create-initial
ceph-deploy admin $NODES
ceph-deploy osd prepare $OSD_LIST
sleep 10
set +x
EOSSH

# bug# workaround 
for (( i=2; i <= $VM_NUM; i++ ))
do
  ssh root@${NAME_BASE}${i} "reboot"
done
sleep 90

ssh cephadm@$MASTER <<EOSSH
sudo ceph osd pool create iscsi 64 64
sudo ceph osd pool create rbd 64 64
sudo ceph osd pool create nfs 64 64
sleep 180
#DEPLOY RGW 
ceph-deploy install --rgw ${NAME_BASE}2
ceph-deploy --overwrite-conf rgw  create ${NAME_BASE}2
EOSSH

cat <<EOF > /tmp/deploy_openAttic_SES4.sh
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

#scp /tmp/deploy_openAttic.sh root@${NAME_BASE}5:/tmp/
#ssh root@${NAME_BASE}5 "chmod +x /tmp/deploy_openAttic.sh"
#ssh root@${NAME_BASE}5 "su - cephadm -c 'source /tmp/deploy_openAttic.sh'"

#ses4qa3_ip_addr=$(cat /etc/hosts|grep ses4qa3|awk '{print $1}')
#
## DEPLOY IGW @3rd node 
#cat <<EOF > /tmp/lrbd.conf
#{
#    "auth": [
#        {
#            "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
#            "authentication": "none"
#        }
#    ],
#    "targets": [
#        {
#            "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
#            "hosts": [
#                {
#                    "host": "ses4qa3.qatest",
#                    "portal": "east"
#                }
#            ]
#        }
#    ],
#    "portals": [
#        {
#            "name": "east",
#            "addresses": [
#                "$ses4qa3_ip_addr"
#            ]
#        }
#    ],
#    "pools": [
#        {
#            "pool": "iscsi",
#            "gateways": [
#                {
#                    "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
#                    "tpg": [
#                        {
#                            "image": "demo"
#                        }
#                    ]
#                }
#            ]
#        }
#    ]
#    }
#EOF
#
#cat <<EOF > /tmp/deploy_IGW.sh
#set -x
#sudo rbd -p iscsi create --size=2G demo
#sudo rbd -p iscsi ls 
#sudo zypper in -y -t pattern ceph_iscsi 
#sudo systemctl enable lrbd
#sudo lrbd -f /tmp/lrbd.conf 
#sudo systemctl start lrbd 
#sudo systemctl status lrbd -l 
#sudo targetcli ls 
#set +x
#EOF
#
#scp /tmp/lrbd.conf root@${NAME_BASE}3:/tmp/
#scp /tmp/deploy_IGW.sh root@${NAME_BASE}3:/tmp/
#ssh root@${NAME_BASE}3 "chmod +x /tmp/deploy_IGW.sh"
#ssh root@${NAME_BASE}3 "su - cephadm -c 'source /tmp/deploy_IGW.sh'"
#
