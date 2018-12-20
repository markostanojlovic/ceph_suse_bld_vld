#!/bin/bash

cfg=/home/mstan/github/ceph_suse_bld_vld/cfg/maiax86_64.cfg
cd /home/mstan/github/ceph_suse_bld_vld/

set -ex 

./1_srv_prep/reset_ses_vms.sh $cfg
./2_deploy/get_ISO_add_REPO.sh $cfg
./2_deploy/salt_setup.sh $cfg

echo "Result: OK"

set +ex
