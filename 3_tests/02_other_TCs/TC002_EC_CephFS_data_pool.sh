#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

ssh root@$MASTER 'bash -s' < 3_tests/master/create_EC_CephFS_pool.sh >> $LOG 2>&1
# TODO client test 
#    - assuming that ses5node2 is the MDS node  TODO
ssh root@$MASTER ceph auth list 2>/dev/null|grep -A 1 client.admin|grep key| awk -F ':' '{print $2}'|tr -d ' ' > /tmp/admin.secret
scp /tmp/admin.secret root@$CLIENT_NODE:/etc/ceph/
ssh root@$CLIENT_NODE << EOSSH >> $LOG 2>&1
umount -f /mnt 
set -ex
mount -t ceph -o mds_namespace=ec_cephfs ses5node2:/ /mnt -o name=admin,secretfile=/etc/ceph/admin.secret
# write test 
openssl rand -base64 -out /mnt/cephfs_random_$(date +%Y_%m_%d_%H_%M).txt 10000000
# read test 
ls -la /mnt
tail /mnt/cephfs_random*txt
# unmount
umount /mnt
sleep 1
echo "Result: OK"
set +ex
EOSSH

echo "Result: OK"

set +ex 
