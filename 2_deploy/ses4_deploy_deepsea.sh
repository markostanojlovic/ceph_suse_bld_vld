#!/bin/bash

if [[ -z $1 ]]
then
  echo "ERROR: Argument missing. USAGE: .script.sh cfg/CONFIG.cfg"
  exit 1
else 
  source $1
fi

set -ex

# Copy policy.cfg to Master node 
sed "s/__NAMEBASE__/${NAME_BASE}/g" $POLICY_CFG_TEMPLATE > cfg/policy.cfg
scp cfg/policy.cfg root@${NAME_BASE}1:/tmp/

# Deployment script 
DEPL_SCRIPT=/tmp/salt_ses_deploy.sh
cat <<EOF > $DEPL_SCRIPT
set +x
salt-run state.orch ceph.stage.0
salt '*' cmd.run 'zypper up -y'
salt-run state.orch ceph.stage.1
cp /tmp/policy.cfg /srv/pillar/ceph/proposals/policy.cfg
salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.3
salt-run state.orch ceph.stage.4
set -x
EOF

# Deployment
ssh root@$MASTER 'bash -s' < $DEPL_SCRIPT
[ $? -eq 0 ] && echo "Deployment OK" || exit 1

echo "Result: OK"

set +ex
