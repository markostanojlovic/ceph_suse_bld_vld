#!/bin/bash

set -ex

ceph osd tree
disk=$(mount|grep ceph|awk -F '/' '{print $3}'|head -c 3)
osd_id=$(mount|grep ceph|awk -F 'ceph-' '{print $2}'|awk -F 'type' '{print $1}'|head -n 1)
salt-run disengage.safety
salt-run remove.osd $osd_id
# verification
ceph osd tree
systemctl status ceph-osd@${osd_id}.service|grep Active|grep "inactive (dead)" && echo "Service down: OK"
mount|grep ceph|grep $disk || echo "Disk unmounted: OK"

set +ex


