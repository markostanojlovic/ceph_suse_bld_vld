#!/bin/bash
set -ex

zypper in -y deepsea
echo "deepsea_minions: '*'" > /srv/pillar/ceph/deepsea_minions.sls
salt-run state.orch ceph.stage.0
salt-run state.orch ceph.stage.1
echo "mon allow pool delete = true" >> /srv/salt/ceph/configuration/files/ceph.conf.d/global.conf
echo "declare -x POL_CFG=/srv/pillar/ceph/proposals/policy.cfg" >> ~/.profile; .  ~/.profile
cp /tmp/policy.cfg /srv/pillar/ceph/proposals/policy.cfg
salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.3
salt-run state.orch ceph.stage.4
salt-call state.apply ceph.salt-api

echo "Result: OK"

set +ex
