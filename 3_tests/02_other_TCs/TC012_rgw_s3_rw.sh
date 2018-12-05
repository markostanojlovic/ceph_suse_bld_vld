#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

RGW_NODE=$(ssh root@$MASTER cat /etc/ceph/ceph.conf|grep -A 5 client.rgw|grep 'rgw dns name'|awk -F '=' '{print $2}'|tr -d ' ')
RGW_PORT=$(ssh root@$MASTER cat /etc/ceph/ceph.conf|grep -A 5 client.rgw|grep 'rgw frontends'|awk -F '=' '{print $3}'|tr -d '"')
RGW_USER=admin

scp 3_tests/client/rgw_s3.py root@$MASTER:/tmp/
ssh root@$MASTER "python3 /tmp/rgw_s3.py ${RGW_NODE}:${RGW_PORT} $RGW_USER" >> $LOG 2>&1

echo "Result: OK" >> $LOG

set +ex 
