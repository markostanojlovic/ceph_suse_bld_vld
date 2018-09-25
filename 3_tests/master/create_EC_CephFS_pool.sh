#!/bin/bash
#
# Requirement: must be exec on admin node

set -ex

# TODO checking requirements and conditions that need to be met 
# 	- MDS configured and running 
# 	- there is no ec_propile created 
# 	- there is no cephfs_ec_data ceph fs 
# 	- there are no cephfs_ec_data and cephfs_ec_metadata pools

# 1. Create new EC profile named ec_profile
ceph osd erasure-code-profile set ec_profile crush-failure-domain=osd k=4 m=2 --force

# 2. Create a data pool with new profile and metadata replicated pool 
ceph osd pool create cephfs_ec_data 8 8 erasure ec_profile
ceph osd pool create cephfs_ec_metadata 8 8  
ceph osd pool application enable cephfs_ec_data cephfs
ceph osd pool application enable cephfs_ec_metadata cephfs

# 3. Set allow_ec_overwrite option 
ceph osd pool set cephfs_ec_data allow_ec_overwrites true

# 4. Enable new CephFS
ceph fs flag set enable_multiple true --yes-i-really-mean-it
ceph fs new ec_cephfs cephfs_ec_metadata cephfs_ec_data
ceph fs ls 

echo "Result: OK"

set +ex
