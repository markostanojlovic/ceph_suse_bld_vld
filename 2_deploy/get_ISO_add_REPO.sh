#!/bin/bash
# Name: 	get_ISO_add_REPO.sh
# Usage: 	get_ISO_add_REPO.sh ENV_CONF_FILE_PATH 
# Example:      ./2_deploy/get_ISO_add_REPO.sh cfg/maiax86_64.cfg 
# Desc:		Downloading ISO image on each host and adding it as repo

[[ -z $1 ]] && exit 1 || source $1

iso_download_url=$REPO_URL
iso_name=${iso_download_url##*/}

for (( i=1; i <= $VM_NUM; i++ ))
do
  # trust always gpg key
  ssh root@${NAME_BASE}${i} "sed -i -e '/^# repo_gpgcheck/a\gpgcheck = off' /etc/zypp/zypp.conf"
  # allow vendor change 
  ssh root@${NAME_BASE}${i} "sed -i -e '/^# solver.allowVendorChange/a\solver.allowVendorChange = true' /etc/zypp/zypp.conf"
  # download and add repo from iso 
  for repo in $(cat $REPO_FILE); do
    iso_download_url=$repo
    iso_name=${iso_download_url##*/}
    repo_name=$(echo $iso_download_url|md5sum|cut -c -8)
    ssh root@${NAME_BASE}${i} wget -q -P /tmp/ $iso_download_url
    ssh root@${NAME_BASE}${i} zypper ar -c -f "iso:/?iso=/tmp/${iso_name}" $repo_name
  done
  # ssh root@${NAME_BASE}${i} zypper ref
  # ssh root@${NAME_BASE}${i} rpm --rebuilddb # old workaournd
done 

