#!/bin/bash
# Name: 	run.sh
# Usage:	./run.sh ENV_CONF_FILE_PATH REPO_URL_FILE_PATH
# Example:	./run.sh ...
# Desc:		Runnig scripts for deploying and testing SES

[[ -z $1 || -z $2 ]] && (echo "Error: Input arguments are missing.";echo "Usage example: ";echo "./run.sh 1_srv_prep/reset_ses_vms_maiax86.config 2_deploy/REPO_ISO_URL_x86_64";exit)

sript_start_time=$(date +%s)
set -x 



set +x
# calculating script execution duration
sript_end_time=$(date +%s);script_runtime=$(((sript_end_time-sript_start_time)/60))
echo;echo "Runtime in minutes (clone operation): " $script_runtime

