#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

ssh root@$MASTER 'bash -s' < 3_tests/master/convert_repl_to_EC_pool.sh > $LOG 2>&1

echo "Result: OK"

set +ex 
