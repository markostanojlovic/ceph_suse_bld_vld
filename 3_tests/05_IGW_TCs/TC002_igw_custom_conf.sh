#!/bin/bash
#
# Requirement: must be exec on admin node

set -ex

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)

# preparation: creating pool and images 
POOL_1=igw_1
POOL_2=igw_2
IMG_1=demo_img_1
IMG_2=demo_img_2
IMG_3=demo_img_3
ssh root@$MASTER << OFSSH >> $LOG 2>&1
ceph osd pool delete $POOL_1 $POOL_NAME --yes-i-really-really-mean-it
ceph osd pool delete $POOL_2 $POOL_NAME --yes-i-really-really-mean-it
ceph osd pool create $POOL_1 8 8 
ceph osd pool create $POOL_2 8 8 
ceph osd pool application enable $POOL_1 rbd
ceph osd pool application enable $POOL_2 rbd
rbd create ${POOL_1}/$IMG_1 --size=1G
rbd create ${POOL_1}/$IMG_2 --size=5G
rbd create ${POOL_2}/$IMG_3 --size=3G
rbd -p $POOL_1 ls
rbd -p $POOL_2 ls
OFSSH

# clear old config on all igw nodes
NODES=$(ssh root@$MASTER "salt -C I@roles:igw grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '")
for NODE in $NODES
do 
  ssh root@$MASTER "salt $NODE cmd.run 'lrbd -C'"
done

nodes=($NODES)
HOST_1_FQDN=${nodes[0]}
HOST_2_FQDN=${nodes[1]}
HOST_1=${HOST_1_FQDN%%\.*}
HOST_2=${HOST_2_FQDN%%\.*}
TARGET_1_IP=$(ssh root@$MASTER "salt ${HOST_1}\* network.ip_addrs"|egrep ".*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}.*"|tr -d - |tr -d ' ')
TARGET_2_IP=$(ssh root@$MASTER "salt ${HOST_2}\* network.ip_addrs"|egrep ".*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}.*"|tr -d - |tr -d ' ')
TARGET_1=iqn.2016-11.org.linux-iscsi.igw.x86:sn.target1
TARGET_2=iqn.2016-11.org.linux-iscsi.igw.x86:sn.target2

cat <<EOF > /tmp/igw_custom.conf
{
    "auth": [ { "target": "$TARGET_1", "authentication": "none" }, { "target": "$TARGET_2", "authentication": "none" } ],
    "targets": [ { "target": "$TARGET_1", "hosts": [ { "host": "$HOST_1_FQDN", "portal": "portal-$HOST_1" } ] }, { "target": "$TARGET_2", "hosts": [ { "host": "$HOST_2_FQDN", "portal": "portal-$HOST_2" } ] } ],
    "portals": [ { "name": "portal-$HOST_1", "addresses": [ "$TARGET_1_IP" ] }, { "name": "portal-$HOST_2", "addresses": [ "$TARGET_2_IP" ] } ],
    "pools": [ { "pool": "$POOL_1", "gateways": [ { "host": "$HOST_1_FQDN", "target": "$TARGET_1", "tpg": [ { "portal": "portal-$HOST_1", "image": "$IMG_1" }, { "portal": "portal-$HOST_1", "image": "$IMG_2" } ] } ] }, { "pool": "$POOL_2", "gateways": [ { "host": "$HOST_2_FQDN", "target": "$TARGET_2", "tpg": [ { "portal": "portal-$HOST_2", "image": "$IMG_3" } ] } ] } ]
}
EOF

for NODE in $NODES
do
  scp /tmp/igw_custom.conf root@${NODE}:/tmp/
  ssh root@${NODE} << EOSSH >> $LOG 2>&1
lrbd -f /tmp/igw_custom.conf
lrbd
targetcli ls 
EOSSH
done

ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/igw_client_test.sh $TARGET_1_IP >> $LOG 2>&1
ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/igw_client_test.sh $TARGET_2_IP >> $LOG 2>&1

echo "Result: OK" >> $LOG 2>&1

set +ex
