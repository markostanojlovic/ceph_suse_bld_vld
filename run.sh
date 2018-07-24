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

# LOGS
LOG_DIR=depl_$(date +%Y_%m_%d_%H_%M)
LOG_PATH=log/${LOG_DIR}
mkdir -p $LOG_PATH

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
echo "Deployment..."
ssh_master 'bash -s' < 2_deploy/ses_deploy_deepsea.sh > ${LOG_PATH}/TC001_ses_deploy_deepsea.log 2>&1
[ $? -eq 0 ] && echo "Deployment OK" || exit 1

sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes (deployment): " $script_runtime;echo

########################################################
# TEST SUITE/TESTS

## Preparation 
### Copying helper script to all hodes 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  scp rc/node_helper.sh root@${NAME_BASE}${i}:/tmp/
done

## Basic TCs
./3_tests/01_basic_TCs/TC001_deployment_after_checks.sh $1 $LOG_PATH
./3_tests/01_basic_TCs/TC002_rm_OSD_with_deepsea.sh $1 $LOG_PATH
./3_tests/01_basic_TCs/TC003_add_OSD_with_deepsea.sh $1 $LOG_PATH
./3_tests/01_basic_TCs/TC004_rm_OSD_manually.sh $1 $LOG_PATH
./3_tests/01_basic_TCs/TC005_cache_tier.sh $1 $LOG_PATH
./3_tests/01_basic_TCs/TC006_EC.sh $1 $LOG_PATH
./3_tests/01_basic_TCs/TC007_igw_basic.sh $1 $LOG_PATH

## Other TCs
./3_tests/02_other_TCs/TC015_convert_repl_to_EC_pool.sh $1 $LOG_PATH

########################################################

set +x
# calculating script execution duration
sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes : " $script_runtime

