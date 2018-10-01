#!/bin/bash
echo "================================================================"

set -ex 

source src/helper.sh
source_cfg $@
echo $NAME_BASE
LOG=$(setup_log_path $@)
echo "Log path: " $LOG

# TODO check this, it's already done in deployment script
#ssh root@$MASTER "salt-run proposal.populate format=filestore name=qatest" >> $LOG 2>&1
#ssh root@$MASTER "sed -i 's/profile-default/profile-qatest/g' /srv/pillar/ceph/proposals/policy.cfg" >> $LOG 2>&1
ssh root@$MASTER "salt-run state.orch ceph.migrate.policy" >> $LOG 2>&1
# TODO verify that policy and profiles are populated correctly 
ssh root@$MASTER "salt-run disengage.safety" >> $LOG 2>&1
ssh root@$MASTER "salt-run state.orch ceph.migrate.osds" >> $LOG 2>&1

# TODO make a better check, now, manuall check needs to be done 
echo
echo "DONT forget to manually check profiles"
echo

echo "Result: OK" >> $LOG 2>&1

set +ex 
