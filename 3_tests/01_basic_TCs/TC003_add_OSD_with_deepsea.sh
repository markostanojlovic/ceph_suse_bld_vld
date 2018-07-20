#!/bin/bash

set -ex

ceph osd tree
lsblk
salt-run state.orch ceph.stage.3
# verification
ceph osd tree
#systemctl status ceph-osd@${osd_id}.service|grep Active|grep "active" && echo "Service up: OK"
mount|grep ceph

set +ex


