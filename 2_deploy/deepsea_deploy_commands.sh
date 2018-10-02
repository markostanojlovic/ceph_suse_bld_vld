#!/bin/bash
set -ex

echo "deepsea_minions: '*'" > /srv/pillar/ceph/deepsea_minions.sls
# disable restart in stage 0
#sed -i "s/default/default-update-no-reboot/g" /srv/salt/ceph/stage/prep/master/init.sls
#sed -i "s/default/default-update-no-reboot/g" /srv/salt/ceph/stage/prep/minion/init.sls

# bug#1100083 workaround 
#sed -i 's/-collector/--collector/g' /srv/salt/ceph/monitoring/prometheus/exporters/node_exporter.sls
# bug with rpm database: Failed to cache rpm database (1).
#salt \* cmd.run "rpm --rebuilddb"

salt-run state.orch ceph.stage.0
salt-run state.orch ceph.stage.1
#cat <<EOF > /srv/salt/ceph/rgw/users/users.d/qausers.yml
#- { uid: "admin", name: "Admin", email: "admin@demo.com", system: True }
#- { uid: "mstan", name: "mstan admin", email: "mstanadmin@demo.com", system: True }
#EOF
echo "mon allow pool delete = true" >> /srv/salt/ceph/configuration/files/ceph.conf.d/global.conf
echo "declare -x POL_CFG=/srv/pillar/ceph/proposals/policy.cfg" >> ~/.profile; .  ~/.profile
cp /tmp/policy.cfg /srv/pillar/ceph/proposals/policy.cfg
# --------------------------------------------------------------------------------
# remove one OSD for the purpose of testing disk replacement with different drive 
cd /srv/pillar/ceph/proposals/profile-default/stack/default/ceph/minions
FILE=$(ls|tail -n 1) # ses5node5
cat $FILE|head -n -2 > tmp.file; cat tmp.file > $FILE;rm tmp.file
cd -
# --------------------------------------------------------------------------------
salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.3
sed -i "/Transports/a Squash = No_Root_Squash;" /srv/salt/ceph/ganesha/files/ganesha.conf.j2
sed -i "s|'openattic' in self.data\[node\]\['roles'\]|'openattic' in self.data\[node\]\['roles'\] and 'rgw' in self.data\[node\]\['roles'\]|" /srv/modules/runners/validate.py
# Any changes made to the iSCSI Gateway configuration using the lrbd command are not visible to DeepSea and openATTIC.
# To import your manual changes, you need to export the iSCSI Gateway configuration to a file: 
# /srv/salt/ceph/igw/cache/lrbd.conf
# echo "igw_config: default-ui" >> /srv/pillar/ceph/stack/global.yml
# solving bug#1049669 problem with python socket module, gethostname()
sed -i "s/, host=True//g" /srv/salt/ceph/igw/files/lrbd.conf.j2
salt-run state.orch ceph.stage.4
salt-call state.apply ceph.salt-api

echo "Result: OK"

set +ex
