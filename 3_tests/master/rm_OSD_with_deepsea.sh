#!/bin/bash

set -ex

source /tmp/node_helper.sh
ceph osd tree
osd_id=$(_get_osd_id)
salt-run disengage.safety
salt-run remove.osd $osd_id force=True
# verification
ceph osd tree
systemctl status ceph-osd@${osd_id}.service|grep Active|grep "inactive (dead)" && echo "Service down: OK"
mount|grep ceph|grep $osd_id || echo "Disk unmounted: OK"

echo "Result: OK"

set +ex


