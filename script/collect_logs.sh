#!/bin/bash
# script for collecting journalctl logs on all nodes
# and filtering them for errors

source config/CONFIG

date1=${1}' '${2}
date2=${3}' '${4}
script_name=$5

# directory for storing logs
LOG_DIR=${BASEDIR}/log/test_case-${script_name}-$(date +%Y_%m_%d_%H_%M)
mkdir $LOG_DIR

for (( NODE_NUMBER=1; NODE_NUMBER <=$VM_NUM; NODE_NUMBER++ ))
do
  scp ${BASEDIR}/script/get_journalctl_logs.sh ${VM_NAME_BASE}${NODE_NUMBER}:/tmp/
  ssh ${VM_NAME_BASE}${NODE_NUMBER} chmod +x /tmp/get_journalctl_logs.sh
  ssh ${VM_NAME_BASE}${NODE_NUMBER} "journalctl --sync"
  ssh ${VM_NAME_BASE}${NODE_NUMBER} /tmp/get_journalctl_logs.sh $date1 $date2 $script_name
  scp ${VM_NAME_BASE}${NODE_NUMBER}:/tmp/*_${script_name}_log ${LOG_DIR}/ 2>/dev/null
  scp ${VM_NAME_BASE}${NODE_NUMBER}:/tmp/journal_err_log ${LOG_DIR}/journal_err_log_${VM_NAME_BASE}${NODE_NUMBER} 2>/dev/null
done

cp $6 $LOG_DIR/TEST_CASE_RUN_log
