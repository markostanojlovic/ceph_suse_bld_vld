#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG


NFS_NODES=$(ssh root@$MASTER "salt -C I@roles:ganesha grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '")
for NODE in $NFS_NODES
do 
  ssh root@$MASTER salt $NODE service.status nfs-ganesha|grep True
  ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/NFS_mount_tests.sh $NODE > $LOG 2>&1
done

echo "Result: OK"

set +ex 
