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
  ssh root@$MASTER "salt $NODE cmd.run 'lrbd -C'"
  HOSTNAME_FQDN=$NODE
done

HOSTNAME_SHORT=${HOSTNAME_FQDN%%\.*}
TARGET_IP=$(ssh root@$MASTER "salt ${HOSTNAME_SHORT}\* network.ip_addrs"|egrep ".*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}.*"|tr -d - |tr -d ' ')
TARGET=iqn.2016-11.org.linux-iscsi.igw.x86:sn.target1

cat <<EOF > /tmp/igw_custom.conf
{
    "auth": [ { "target": "iqn.2016-11.org.linux-iscsi.igw.x86:sn.target1", "authentication": "none" } ],
    "targets": [ { "target": "iqn.2016-11.org.linux-iscsi.igw.x86:sn.target1", "hosts": [ { "host": "$HOSTNAME_FQDN", "portal": "portal-$HOSTNAME_SHORT" } ] } ],
    "portals": [ { "name": "portal-$HOSTNAME_SHORT", "addresses": [ "$TARGET_IP" ] } ],
    "pools": [ { "pool": "$POOL_NAME", "gateways": [ { "target": "$TARGET", "tpg": [ { "image": "$IMG_NAME_1" }, { "image": "$IMG_NAME_2" } ] } ] } ]
}
EOF

scp /tmp/igw_custom.conf root@${HOSTNAME_FQDN}:/tmp/

ssh root@${HOSTNAME_FQDN} << EOSSH >> $LOG 2>&1
cat /tmp/igw_custom.conf
lrbd -f /tmp/igw_custom.conf
lrbd
targetcli /iscsi/${TARGET}/tpg1 enable
targetcli ls 
EOSSH

ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/igw_client_test.sh $TARGET_IP >> $LOG 2>&1

echo "Result: OK" >> $LOG 2>&1

set +ex
