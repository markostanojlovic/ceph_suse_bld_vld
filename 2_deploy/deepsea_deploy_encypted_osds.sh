#!/bin/bash
set -ex

echo "deepsea_minions: '*'" > /srv/pillar/ceph/deepsea_minions.sls

salt-run state.orch ceph.stage.0
salt-run state.orch ceph.stage.1
echo "mon allow pool delete = true" >> /srv/salt/ceph/configuration/files/ceph.conf.d/global.conf
echo "declare -x POL_CFG=/srv/pillar/ceph/proposals/policy.cfg" >> ~/.profile; .  ~/.profile
salt-run proposal.populate encryption=dmcrypt name=qatest
cp /tmp/policy.cfg /srv/pillar/ceph/proposals/policy.cfg
sed -i 's/profile-default/profile-qatest/g' /srv/pillar/ceph/proposals/policy.cfg
# --------------------------------------------------------------------------------
# remove one OSD for the purpose of testing disk replacement with different drive 
cd /srv/pillar/ceph/proposals/profile-qatest/stack/default/ceph/minions
FILE=$(ls|tail -n 1) # ses5node5
cat $FILE|head -n -3 > tmp.file; cat tmp.file > $FILE;rm tmp.file
cd -
# --------------------------------------------------------------------------------
salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.3
sed -i "/Transports/a Squash = No_Root_Squash;" /srv/salt/ceph/ganesha/files/ganesha.conf.j2
sed -i "s|'openattic' in self.data\[node\]\['roles'\]|'openattic' in self.data\[node\]\['roles'\] and 'rgw' in self.data\[node\]\['roles'\]|" /srv/modules/runners/validate.py
sed -i "s/, host=True//g" /srv/salt/ceph/igw/files/lrbd.conf.j2
salt-run state.orch ceph.stage.4
salt-call state.apply ceph.salt-api

echo "Result: OK"

set +ex
