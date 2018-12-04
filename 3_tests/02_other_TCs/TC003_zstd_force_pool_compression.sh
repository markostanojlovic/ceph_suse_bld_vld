#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

pool_name=qapool_zstd

ssh root@$MASTER 'bash -s' < 3_tests/master/compression_zstd_force_pool.sh $pool_name >> $LOG 2>&1
ssh root@$MASTER 'bash -s' < 3_tests/client/rbd_client_test.sh $pool_name >> $LOG 2>&1

echo "Result: OK"

set +ex 
