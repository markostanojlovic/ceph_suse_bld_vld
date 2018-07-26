#!/bin/bash
# Name: 	run.sh
# Usage:	./run.sh ENV_CONF_FILE_PATH 
# Example:	./run.sh cfg/maiax86_64.cfg 
# Desc:		Runnig scripts for deploying and testing SES

if [[ -z $1 ]]
then
  echo "ERROR: ENV_CONF argument missing."
  echo "Example:"
  echo "./run.sh cfg/maiax86_64.cfg"
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
./2_deploy/get_ISO_add_REPO.sh $1

# SALT-STACK
./2_deploy/salt_setup.sh $1

# SES DEPLOY
source $1
sed "s/__NAMEBASE__/${NAME_BASE}/g" cfg/policy.cfg.tmpl > cfg/policy.cfg
scp cfg/policy.cfg root@${NAME_BASE}1:/tmp/
echo "Deployment..."
ssh root@$MASTER 'bash -s' < 2_deploy/ses_deploy_deepsea.sh > ${LOG_PATH}/TC001_ses_deploy_deepsea.log 2>&1
[ $? -eq 0 ] && echo "Deployment OK" || exit 1

sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes (deployment): " $script_runtime;echo
#
#########################################################
## TEST SUITE/TESTS
#
### Preparation 
#### Copying helper script to all hodes 
#for (( i=1; i <= $VM_NUM; i++ ))
#do 
#  scp src/node_helper.sh root@${NAME_BASE}${i}:/tmp/
#done
#
### Basic TCs
#./3_tests/01_basic_TCs/TC001_deployment_after_checks.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC002_rm_OSD_with_deepsea.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC003_add_OSD_with_deepsea.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC004_rm_OSD_manually.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC005_cache_tier.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC006_EC.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC007_igw_basic.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC008_RGW_basic.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC009_RBD_basic.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC010_NFS_ganesha_basic.sh $1 $LOG_PATH
#./3_tests/01_basic_TCs/TC011_CephFS_basic.sh $1 $LOG_PATH
#
### Other TCs
#./3_tests/02_other_TCs/TC015_convert_repl_to_EC_pool.sh $1 $LOG_PATH
#
### NFS
#./3_tests/04_NFS_TCs/TC001_NFS_active_passive_HA.sh $1 $LOG_PATH
#
### Removing services
#./3_tests/01_basic_TCs/TC012_rm_services_with_deepsea.sh $1 $LOG_PATH
#
#########################################################
#set +x
#
#REPORT_SUMM=$LOG_PATH/REPORT_SUMMARY
#> $REPORT_SUMM
#
## CHECKING LOGS
#echo 
#echo '=========================================================================================' >> $REPORT_SUMM
#for TC_log in $(find ./${LOG_PATH}/ -name "TC*"|awk -F ':' '{print $1}')
#do 
#  egrep -q "^Result: OK" $TC_log && echo 'Result: OK | '$TC_log || echo 'FAILED     | '$TC_log >> $REPORT_SUMM
#done
#echo '=========================================================================================' >> $REPORT_SUMM
## calculating script execution duration
#sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
#echo "Runtime in minutes : " $script_runtime >> $REPORT_SUMM
#echo '=========================================================================================' >> $REPORT_SUMM
#
#cat $REPORT_SUMM
echo
