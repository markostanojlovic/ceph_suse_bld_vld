#!/bin/bash
# Name: 	run.sh
# Usage:	./run.sh ENV_CONF_FILE_PATH REPO_URL_FILE_PATH
# Example:	./run.sh cfg/maiax86_64.cfg cfg/REPO_ISO_URL_x86_64
# Desc:		Runnig scripts for deploying and testing SES

if [[ -z $1 || -z $2 ]]
then
  echo "ERROR: ENV_CONF argument missing."
  echo "Example:"
  echo "./run.sh cfg/maiax86_64.cfg cfg/REPO_ISO_URL_x86_64"
  exit 1
fi

sript_start_time=$(date +%s)
set -x 

# VMs 
./1_srv_prep/reset_ses_vms.sh $1

# REPO ISO 
./2_deploy/get_ISO_add_REPO.sh $1 $2

# SALT-STACK
./2_deploy/salt_setup.sh $1

# SES DEPLOY
source $1
sed "s/__NAMEBASE__/${NAME_BASE}/g" cfg/policy.cfg.tmpl > cfg/policy.cfg
scp cfg/policy.cfg root@${NAME_BASE}1:/tmp/
ssh root@${NAME_BASE}1 'bash -s' < 2_deploy/ses_deploy_deepsea.sh

# TEST SUITE


set +x
# calculating script execution duration
sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes (clone operation): " $script_runtime

