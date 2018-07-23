#!/bin/bash
#
# Requirement: script needs to be exec on admin node 

set -ex

# preparation: deleting pools if they already exist
ceph osd pool delete cold-storage cold-storage --yes-i-really-really-mean-it
ceph osd pool delete hot-storage hot-storage --yes-i-really-really-mean-it

ceph osd pool create cold-storage 32 32 replicated
ceph osd pool create hot-storage 32 32 replicated
ceph osd tier add cold-storage hot-storage
ceph osd tier cache-mode hot-storage writeback
ceph osd tier set-overlay cold-storage hot-storage
ceph osd pool set hot-storage hit_set_type bloom
ceph osd pool set hot-storage hit_set_count 3
ceph osd pool set hot-storage hit_set_period 1200
ceph osd pool set hot-storage target_max_bytes 20000000
for i in 1 2 3 4 5
do 
  base64 /dev/urandom | head --bytes=4MB > 4MB.random.txt.file.$i
  rados -p hot-storage put obj_$i 4MB.random.txt.file.$i
done
echo "##### hot-storage ####"
rados -p hot-storage ls
echo "#### cold-storage ####"
rados -p cold-storage ls
echo "######################"
ceph osd tier remove-overlay cold-storage
ceph osd tier remove cold-storage hot-storage
for i in 1 2 3 4 5
do 
  base64 /dev/urandom | head --bytes=4MB > 4MB.random.txt.file.$i
  rados -p hot-storage put obj_2_$i 4MB.random.txt.file.$i
done
echo "##### hot-storage ####"
rados -p hot-storage ls
echo "#### cold-storage ####"
rados -p cold-storage ls
echo "######################"

echo "Result: OK"

set +ex


