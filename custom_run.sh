#!/bin/bash

./1_srv_prep/reset_ses_vms.sh cfg/maiax86_64.cfg
./2_deploy/get_ISO_add_REPO.sh cfg/maiax86_64.cfg
./2_deploy/salt_setup.sh cfg/maiax86_64.cfg
scp  cfg/policy.cfg root@ses5node1:/tmp/
ssh root@ses5node1 'bash -sx' < 2_deploy/deepsea_deploy_filestore.sh 
