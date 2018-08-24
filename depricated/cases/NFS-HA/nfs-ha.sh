#!/bin/bash
# Script for deploying and testing NFS ganesha HA feature
# REQUIREMENTS:
# - there are exactly 2 nfs ganesha nodes in ceph cluster
# - there is connection do download HA ISO images from mirror.suse.cz
# INPUT ARGUMENTS:
# - $1 = ha_ip_address

set -ex
source script/helper.sh
set_NFS_HA_IP $1
nfs_ganesha_disable_service
ha_repo_setup
set_NFS_HA_primary_node
nfs_ha_cluster_bootstrap
# NFS client R/W test
ha_ganesha_ip_failover
# NFS client R/W test
ha_ganesha_ip_failover
# NFS client R/W test
echo "Result: OK"
