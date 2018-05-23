#!/bin/bash
#######################################################################################
# Description: 	Script for creating VMs and depolying SES
# Author:  		Marko Stanojlovic, QA Ceph @ SUSE Enterprise Storage
# Contact: 		mstanojlovic@suse.com
# Usage: 		./deploy_ceph.sh
#
# Expected script duration: ~30min
#
# *** README: ***
# - CHECK MANUAL CONFIG PART BEFORE TO RUN
# - Run as root
# - Make sure there is SUFICIENT SPACE in $VM_DIR - place where VMs are stored
# - VM names are $VM_NAME_BASE + incrementing suffix EXAMPLE: ses5node1, ses5node2, etc.
# - SALT MASTER node is the first VM "ses5node1"
# - IP addresses are starting from x.x.x.151
#
#######################################################################################

sript_start_time=$(date +%s)

set -x
# loading configuration
source config/CONFIG
# logs
LOG_DIR=$(${BASEDIR}/script/log_init.sh|grep run)
echo ${BASEDIR}/log/$LOG_DIR > ${BASEDIR}/config/LAST_DEPLOY_LOG_DIR
# preparing the host
source ${BASEDIR}/script/prepare_host.sh
# creating VMs
source ${BASEDIR}/script/create_VMs.sh
# checking while all VM shut off
while sleep 5;do runningvms=$(virsh list|grep ${VM_NAME_BASE});if [[ $runningvms == '' ]];then echo 'NO VMs running...';break;fi;done
# adding OSD disks to VMs
source ${BASEDIR}/script/add_OSDs.sh $VM_NAME_BASE $VM_NUM "$OSD_DEST_LIST"
# start all VMs
for (( NODE_NUMBER=1; NODE_NUMBER <=$VM_NUM; NODE_NUMBER++ ));do virsh start ${VM_NAME_BASE}${NODE_NUMBER};done
# waiting for autoyast script to be completed/home/mstanojlovic/github/ceph_suse_bld_vld
_wait_autoyast_script_completion
# prepare VMs (copy hosts file, install salt, configure salt-master)
source ${BASEDIR}/script/prepare_VMs.sh
# copy policy.cfg
scp ${BASEDIR}/config/policy.cfg $MASTER:/tmp/
# zypper upgrade
_run_command_on_remote_host $MASTER "salt \* cmd.run 'zypper up -y 1>/dev/null'"
# reboot all VMs
_run_command_on_remote_host $MASTER "salt --async \* cmd.run 'shutdown -r +1'"
sleep 60
# wait until all VMs are up
_wait_for_all_VMs_up
# DEPLOY SES CLUSTER
#_run_script_on_remote_host $MASTER ${BASEDIR}/script/cluster_deploy.sh
# configure rsyslog sending logs to journal
source  ${BASEDIR}/script/configure_rsyslog.sh
# perform basic cluster checks
#_run_script_on_remote_host $MASTER ${BASEDIR}/script/basic_checks.sh
# basic client tests *ses_client VM up and running*
#source ${BASEDIR}/script/client_tests.sh
# collect deployment logs
source ${BASEDIR}/script/collect_deployment_logs.sh

set +x
# calculating script execution duration
sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes: " $script_runtime
