#!/bin/bash
sleep 6
for (( NODE_NUMBER=1; NODE_NUMBER <=$VM_NUM; NODE_NUMBER++ ))
do
  ssh ${VM_NAME_BASE}${NODE_NUMBER} "journalctl --sync"
  ssh ${VM_NAME_BASE}${NODE_NUMBER} "journalctl -p err --until '+0' > /tmp/journal_err_log"
  scp ${VM_NAME_BASE}${NODE_NUMBER}:/tmp/journal_err_log ${BASEDIR}/log/${LOG_DIR}/journal_err_log_${VM_NAME_BASE}${NODE_NUMBER}
done
