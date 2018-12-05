#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

# client node also has admin role ***
ssh root@$CLIENT_NODE 'bash -s' < 3_tests/client/rbd_persistent_map.sh >> $LOG 2>&1

echo "Result: OK"

set +ex 
