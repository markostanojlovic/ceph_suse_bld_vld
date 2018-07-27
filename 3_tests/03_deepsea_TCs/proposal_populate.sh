#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

ssh root@$MASTER salt-run proposal.populate encryption=dmcrypt name=qatest >> $LOG 2>&1
ssh root@$MASTER "cat \$(ls /srv/pillar/ceph/proposals/profile-qatest/stack/default/ceph/minions/*|tail -n 1 )" >> $LOG 2>&1

echo "Result: OK"

set +ex 
