#!/bin/bash

set -x

./1_srv_prep/reset_ses_vms.sh cfg/thunderx9aarch_SES4.cfg
./1_srv_prep/register_and_update.sh cfg/thunderx9aarch_SES4.cfg
./2_deploy/ses4_deploy_ceph-deploy.sh cfg/thunderx9aarch_SES4.cfg
ssh root@ses4node1 zypper migration --quiet --non-interactive --allow-vendor-change
./2_deploy/salt_setup.sh cfg/thunderx9aarch_SES4.cfg

set +x

