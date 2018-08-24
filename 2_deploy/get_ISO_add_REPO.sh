#!/bin/bash
# Name: 	get_ISO_add_REPO.sh
# Usage: 	get_ISO_add_REPO.sh ENV_CONF_FILE_PATH 
# Example:      ./2_deploy/get_ISO_add_REPO.sh cfg/maiax86_64.cfg 
# Desc:		Downloading ISO image on each host and adding it as repo

if [[ -z $1 ]]
then
  echo "ERROR: Argument missing."
  echo "Example:"
  echo "./2_deploy/get_ISO_add_REPO.sh cfg/maiax86_64.cfg"
  exit 1
else 
  source $1
fi

iso_download_url=$REPO_URL
iso_name=${iso_download_url##*/}

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
  ssh root@${NAME_BASE}${i} zypper ref
  ssh root@${NAME_BASE}${i} rpm --rebuilddb
done 

