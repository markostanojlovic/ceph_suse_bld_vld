#!/bin/bash
# Script name: get_ISO_add_REPO.sh
# Usage: get_ISO_add_REPO.sh __REPO__ __LOCAL_CONF__
#        get_ISO_add_REPO.sh REPO_ISO_URL_x86_64 reset_ses_vms_maiax86.config

# Downloading ISO image and adding it as repo on each host
# Setting up zipper config 

[[ -z $1 || -z $2 ]] && (echo "Error: Input arguments are missing.";echo "Usage example: ";echo "./2_deploy/get_ISO_add_REPO.sh 2_deploy/REPO_ISO_URL_x86_64 1_srv_prep/reset_ses_vms_maiax86.config";exit)

iso_download_url=$(cat $1)
iso_name=${iso_download_url##*/}
source ../1_srv_prep/$2

# download iso
for (( i=1; i <= $VM_NUM; i++ ))
do
  # download iso 
  ssh root@${NAME_BASE}${i} wget -q -P /tmp/ $iso_download_url
  # trust always gpg key
  ssh root@${NAME_BASE}${i} "sed -i -e '/^# repo_gpgcheck/a\gpgcheck = off' /etc/zypp/zypp.conf"
  # allow vendor change 
  ssh root@${NAME_BASE}${i} "sed -i -e '/^# solver.allowVendorChange/a\solver.allowVendorChange = true' /etc/zypp/zypp.conf"
  # add repo
  ssh root@${NAME_BASE}${i} zypper ar -c -f "iso:/?iso=/tmp/${iso_name}" SES
done 

