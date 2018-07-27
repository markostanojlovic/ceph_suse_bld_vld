#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

# get all RGW nodes salt \* pillar.get roles
RGW_NODES=$(ssh root@$MASTER "salt -C I@roles:rgw grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '")
for NODE in $RGW_NODES
do
  # check if service is running systemctl status ceph-radosgw@rgw.nodename.service
  ssh root@$MASTER "salt $NODE service.status ceph-radosgw@rgw.${NODE%\.*}|grep True"
  # get TCP port ss -l -p -n|grep tcp|grep rados
  TCP_PORT=$(ssh root@$NODE ss -l -p -n|grep tcp|grep rados|awk -F '*:' '{print $2}'|tr -d ' ')
  ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/rgw_client_test.sh $NODE $TCP_PORT >> $LOG 2>&1
done

# Verify user is created for S3 interface
ssh root@$MASTER radosgw-admin user list|grep admin

echo "Result: OK"

set +ex 
