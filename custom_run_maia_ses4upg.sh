#!/bin/bash

./1_srv_prep/reset_ses_vms.sh cfg/maiax86_64_ses4.cfg
./2_deploy/ses4_deploy_ceph-deploy.sh cfg/maiax86_64_ses4.cfg
