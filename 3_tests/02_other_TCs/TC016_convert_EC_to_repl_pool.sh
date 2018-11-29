#!/bin/bash
#
# Requirement: must be exec on admin node

set -ex

echo
echo "TC blocked by bug#1102242"
echo
exit 0
# preparation: deleting pool if they exist
ceph osd pool delete new_repl_pool new_repl_pool --yes-i-really-really-mean-it
ceph osd pool delete test_ec_pool test_ec_pool --yes-i-really-really-mean-it
# create replicated pool
ceph osd pool create test_ec_pool 16 16 erasure default
ceph osd pool application enable test_ec_pool rbd
# add obj into the pool
for i in 1 2 3 4 5
do 
  file_name=/tmp/random_${i}.txt
  openssl rand -base64 -out $file_name 1000000 # 1.3MB
  rados -p test_ec_pool put object_${i} $file_name
  ceph osd map test_ec_pool object_${i}
done
rados -p test_ec_pool ls|grep object
# create new EC pool
ceph osd pool create new_repl_pool 16 16 replicated
ceph osd pool application enable new_repl_pool rbd
# setup cache tier 
ceph osd tier add new_repl_pool test_ec_pool --force-nonempty
ceph osd tier cache-mode test_ec_pool forward --yes-i-really-mean-it
# Force the cache pool to move all objects to the new pool
rados -p test_ec_pool cache-flush-evict-all
# Switch all clients to the new pool
ceph osd tier set-overlay new_repl_pool test_ec_pool
# verify all objects are in the new EC pool
rados -p test_ec_pool ls|grep object || echo "Pool empty: OK"
rados -p new_repl_pool ls|grep object
# remove the overlay and the old cache pool 'testpool'
ceph osd tier remove-overlay new_repl_pool
ceph osd tier remove new_repl_pool test_ec_pool

echo "Result: OK"

set +ex
