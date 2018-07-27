#!/bin/bash
# Requirements:
# 	- there are exactly 2 nfs ganesha nodes in ceph cluster
# 	- there is connection do download HA ISO images from mirror.suse.cz (for HA installation) 

echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

echo "NFS HA Setup:"
ssh root@$MASTER 'bash -s' < 3_tests/master/NFS_HA_setup.sh $NFS_HA_IP >> $LOG 2>&1
sleep 30
echo "NFS simple client test:"
ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/NFS_simple.sh $NFS_HA_IP >> $LOG 2>&1
echo "Failover:"
ssh root@$MASTER 'bash -s' < 3_tests/master/NFS_HA_failover.sh >> $LOG 2>&1
echo "NFS simple client test:"
ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/NFS_simple.sh $NFS_HA_IP >> $LOG 2>&1
echo "Failover:"
ssh root@$MASTER 'bash -s' < 3_tests/master/NFS_HA_failover.sh >> $LOG 2>&1
echo "NFS simple client test:"
ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/NFS_simple.sh $NFS_HA_IP >> $LOG 2>&1

echo "Result: OK"

set +ex 
