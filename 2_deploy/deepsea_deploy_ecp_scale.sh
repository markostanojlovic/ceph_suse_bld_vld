#!/bin/bash
set -ex

sed -i "/ipv6-loopback/c\::1 localhost ipv6-localhost ipv6-loopback $(hostname)" /etc/hosts 

zypper in -y deepsea
echo "deepsea_minions: '*'" > /srv/pillar/ceph/deepsea_minions.sls
salt-run state.orch ceph.stage.0
salt-run state.orch ceph.stage.1
echo "declare -x POL_CFG=/srv/pillar/ceph/proposals/policy.cfg" >> ~/.profile; .  ~/.profile
echo "\
# Cluster assignment
cluster-ceph/cluster/*.sls
# Common configuration
config/stack/default/global.yml
config/stack/default/ceph/cluster.yml
# Role assignment
role-master/cluster/monses0*.sls
role-admin/cluster/monses*.sls
role-mon/cluster/monses*.sls
role-mgr/cluster/monses*.sls
role-mds/cluster/monses*.sls
# Profile (Hardware) configuration
profile-default/cluster/sesosd*sls
profile-default/stack/default/ceph/minions/sesosd*yml
" > /srv/pillar/ceph/proposals/policy.cfg
salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.3
salt-run state.orch ceph.stage.4

echo "Result: OK"

set +ex
