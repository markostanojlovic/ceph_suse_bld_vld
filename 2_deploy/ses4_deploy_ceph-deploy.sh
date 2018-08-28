#!/bin/bash
# NOTES: 
# 	- only 3 mons: nodes 1,2,3 
#	- rgw deployed at node 2 
#	- oA has to be deployed on admin node, in this is node 5 
#	- igw deployed at node 3

if [[ -z $1 ]]
then
  echo "ERROR: argument missing. USAGE: ./1_srv_prep/reset_ses_vms.sh cfg/maiax86_64.cfg"
  exit 1
else
  source $1
fi

set -ex

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

set +e
# bug# workaround 
for (( i=2; i <= $VM_NUM; i++ ))
do
  ssh root@${NAME_BASE}${i} "reboot"
done
sleep 90
set -e

#---------------------------------------------------------------------------
ssh cephadm@$MASTER <<EOSSH
sudo ceph osd pool create iscsi 64 64
sudo ceph osd pool create rbd 64 64
sudo ceph osd pool create nfs 64 64
sleep 180
#DEPLOY RGW 
ceph-deploy install --rgw ${NAME_BASE}2
ceph-deploy --overwrite-conf rgw  create ${NAME_BASE}2
EOSSH
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# openAttic 
# REQUIREMENT: node has to be admin node, run as root
cat <<EOF > /tmp/deploy_openAttic_SES4.sh
zypper in -y openattic
ceph auth add client.openattic mon 'allow *' osd 'allow *'
ceph auth get client.openattic -o /etc/ceph/ceph.client.openattic.keyring
chmod 644 /etc/ceph/ceph.client.openattic.keyring
chown openattic:openattic /etc/ceph/ceph.client.openattic.keyring
oaconfig install
systemctl status openattic-systemd.service|grep Active
EOF

ssh root@${NAME_BASE}5 'bash -sx' < /tmp/deploy_openAttic_SES4.sh
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# IGW 
TARGET=iqn.2016-11.org.linux-iscsi.igw.x86:sn.target1
HOSTNAME_FQDN=${NAME_BASE}3.$DOMAIN_NAME
HOSTNAME_SHORT=${NAME_BASE}3
TARGET_IP=$(grep $HOSTNAME_SHORT /etc/hosts|awk '{print $1}')
POOL_NAME=iscsi
IMG=demo
ssh root@$MASTER "rbd -p $POOL_NAME create $IMG --size=5G"
cat <<EOF > /tmp/lrbd.conf
{
    "auth": [ { "target": "$TARGET", "authentication": "none" } ],
    "targets": [ { "target": "$TARGET", "hosts": [ { "host": "$HOSTNAME_FQDN", "portal": "portal-$HOSTNAME_SHORT" } ] } ],
    "portals": [ { "name": "portal-$HOSTNAME_SHORT", "addresses": [ "$TARGET_IP" ] } ],
    "pools": [ { "pool": "$POOL_NAME", "gateways": [ { "target": "$TARGET", "tpg": [ { "image": "$IMG" } ] } ] } ]
}
EOF
scp /tmp/lrbd.conf root@${NAME_BASE}3:/tmp/
ssh root@${NAME_BASE}3 <<EOSSH
set -x
sudo zypper in -y -t pattern ceph_iscsi
systemctl enable lrbd
lrbd -f /tmp/lrbd.conf
lrbd
targetcli ls 
set +x
EOSSH
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# NFS-GANESHA - not supported 
#---------------------------------------------------------------------------

echo "Result: OK"

set +ex
