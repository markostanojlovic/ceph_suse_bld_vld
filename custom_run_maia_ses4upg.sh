#!/bin/bash

set -x

./1_srv_prep/reset_ses_vms.sh cfg/maiax86_64_ses4.cfg
./1_srv_prep/register_and_update.sh cfg/maiax86_64_ses4.cfg
./2_deploy/ses4_deploy_ceph-deploy.sh cfg/maiax86_64_ses4.cfg

ssh root@ses4node1 zypper migration --quiet --non-interactive --allow-vendor-change
ssh root@ses4node1 cat /etc/os-release
ssh root@ses4node1 zypper lr

ISO_REPO_url=http://dist.suse.de/install/SUSE-Enterprise-Storage-5.5-M9/SUSE-Enterprise-Storage-5-DVD-x86_64-Build0805-Media1.iso
ISO_REPO_file=${ISO_REPO_url##*/}
VM_NUM=5
NAME_BASE=ses4node
for (( i=1; i <= $VM_NUM; i++ ))
do
  ssh root@${NAME_BASE}${i} "sed -i -e '/^# solver.allowVendorChange/a\solver.allowVendorChange = true' /etc/zypp/zypp.conf"
  ssh root@${NAME_BASE}${i} "sed -i -e '/^# repo_gpgcheck/a\repo_gpgcheck = off' -e '/^# pkg_gpgcheck/a\pkg_gpgcheck = off' /etc/zypp/zypp.conf"
  ssh root@${NAME_BASE}${i} "wget --quiet -P /tmp/ $ISO_REPO_url"
  ssh root@${NAME_BASE}${i} "zypper ar --no-gpgcheck -c -f \"iso:/?iso=/tmp/$ISO_REPO_file\" SES"
done

./2_deploy/salt_setup.sh cfg/maiax86_64_ses4.cfg

set +x
