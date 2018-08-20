#!/bin/bash
#
# Requirement: must be exec on admin node

set -ex

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)

#ssh root@$MASTER "salt-run proposal.populate encryption=dmcrypt name=qatest" >> $LOG 2>&1

# preparation: creating pool and images 
POOL_NAME=igw-imgs
IMG_NAME_1=demo_img_1
IMG_NAME_2=demo_img_2
ssh root@$MASTER << OFSSH >> $LOG 2>&1
ceph osd pool delete $POOL_NAME $POOL_NAME --yes-i-really-really-mean-it
ceph osd pool create $POOL_NAME 8 8 
ceph osd pool application enable $POOL_NAME rbd
rbd create ${POOL_NAME}/$IMG_NAME_1 --size=1G
rbd create ${POOL_NAME}/$IMG_NAME_2 --size=5G
rbd -p $POOL_NAME ls
OFSSH

# clear old config on all igw nodes
NODES=$(ssh root@$MASTER "salt -C I@roles:igw grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '")
for NODE in $NODES
do 
  ssh root@$MASTER salt $NODE cmd.run 'lrbd -C'
  HOSTNAME_FQDN=$NODE
done

HOSTNAME_SHORT=${HOSTNAME_FQDN%%\.*}
TARGET_IP=$(salt ses5node1\* network.ip_addrs|egrep ".*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}.*"|tr -d - |tr -d ' ')

echo "Result: OK" >> $LOG 2>&1

set +ex
