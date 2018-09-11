#!/bin/bash
./1_srv_prep/reset_ses_vms.sh cfg/thunderx9aarch_SES4.cfg
./2_deploy/ses4_deploy_ceph-deploy.sh cfg/thunderx9aarch_SES4.cfg
#./2_deploy/salt_setup.sh cfg/thunderx9aarch_SES4.cfg
#scp  cfg/policy.cfg root@ses5node1:/tmp/
