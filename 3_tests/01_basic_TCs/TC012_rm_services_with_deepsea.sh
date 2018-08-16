#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

ssh root@$MASTER 'bash -s' < 3_tests/master/rm_services_with_deepsea.sh >> $LOG 2>&1

# Add the services back
ssh root@$MASTER mv /srv/pillar/ceph/proposals/policy.cfg.old /srv/pillar/ceph/proposals/policy.cfg
ssh root@$MASTER salt-run state.orch ceph.stage.2
salt -I cluster:ceph mine.update # why?
ssh root@$MASTER salt-run state.orch ceph.stage.4

echo "Result: OK"

set +ex 
