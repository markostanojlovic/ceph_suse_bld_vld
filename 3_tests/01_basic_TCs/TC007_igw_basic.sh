#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

# get which are the igw nodes 
iSCSI_PORTAL=$(ssh root@$MASTER "salt -C I@roles:igw grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '")
# run client test script on client node for each igw node 
for portal in $iSCSI_PORTAL
do
        ssh root@$iSCSI_PORTAL 'lrbd -l;targetcli ls'
        ssh root@${CLIENT_NODE} 'bash -s' < 3_tests/client/igw_client_test.sh $portal >> $LOG 2>&1
done

echo "Result: OK"

set +ex 
