#!/bin/bash

set -ex

source /tmp/node_helper.sh

cp /srv/pillar/ceph/proposals/policy.cfg /srv/pillar/ceph/proposals/policy.cfg.old
sed -i '/igw/d;/rgw/d;/openattic/d;/ganesha/d' /srv/pillar/ceph/proposals/policy.cfg

salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.5

# verification
salt '*' pillar.get roles
for ROLE in igw rgw openattic ganesha
do 
  salt '*' pillar.get roles|grep $ROLE && exit 1 || echo $ROLE " not in pillar roles"
done 

# TODO check each servrice on nodes and verify it's not running 

echo "Result: OK"

set +ex


