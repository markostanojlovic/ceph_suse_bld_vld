#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

# TODO : find a way to assert or check if the new crushmap is as expected
# TODO : create a new replicated rule and move all pools to a new rule

ssh root@$MASTER 'bash -s' < 3_tests/master/CRUSH_split_to_2racks.sh $VM_NUM $NAME_BASE >> $LOG 2>&1

echo "Result: OK"

set +ex 
