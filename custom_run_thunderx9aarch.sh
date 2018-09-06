#!/bin/bash
./1_srv_prep/reset_ses_vms.sh cfg/thunderx9aarch.cfg
./2_deploy/get_ISO_add_REPO.sh cfg/thunderx9aarch.cfg
./2_deploy/salt_setup.sh cfg/thunderx9aarch.cfg
scp  cfg/policy.cfg root@ses5node1:/tmp/
