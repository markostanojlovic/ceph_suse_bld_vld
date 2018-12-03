#!/bin/bash

set -ex

NAME_BASE=$1
ceph osd tree
lsblk
# add vdd on ses5node5/ses6node6 that is excluded in deployment 
salt-run proposal.populate name=new
orig=/srv/pillar/ceph/proposals/profile-default/stack/default/ceph/minions/${NAME_BASE}5.qalab.yml
tail -n 2 /srv/pillar/ceph/proposals/profile-new/stack/default/ceph/minions/${NAME_BASE}5.qalab.yml >> $orig
salt-run state.orch ceph.stage.2
salt-run advise.osds
salt-run state.orch ceph.stage.3
# verification
ceph osd tree
#systemctl status ceph-osd@${osd_id}.service|grep Active|grep "active" && echo "Service up: OK"
mount|grep ceph

echo "Result: OK"

set +ex


