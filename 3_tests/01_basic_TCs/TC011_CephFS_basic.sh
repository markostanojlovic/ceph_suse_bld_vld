#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

CLIENT_ADMIN_KEY=$(ssh root@$MASTER ceph auth list 2>/dev/null|grep -A 1 client.admin|grep key|sed 's/key: //'|tr -d '\t')

MDS_NODES=$(ssh root@$MASTER "salt -C I@roles:mds grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '")
for NODE in $MDS_NODES
do 
  ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/cephFS_client_test.sh $NODE $CLIENT_ADMIN_KEY > $LOG 2>&1
done

echo "Result: OK"

set +ex 
