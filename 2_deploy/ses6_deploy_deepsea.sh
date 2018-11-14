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
DEPL_SCRIPT=2_deploy/deepsea_deploy_commands_ses6.sh

# Deployment
ssh root@$MASTER 'bash -s' < $DEPL_SCRIPT
[ $? -eq 0 ] && echo "Deployment OK" || exit 1

echo "Result: OK"

set +ex
