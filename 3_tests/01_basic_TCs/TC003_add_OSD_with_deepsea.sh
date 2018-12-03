#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

ssh root@$MASTER 'bash -s' < 3_tests/master/add_OSD_with_deepsea.sh $NAME_BASE >> $LOG 2>&1

echo "Result: OK"

set +ex 
