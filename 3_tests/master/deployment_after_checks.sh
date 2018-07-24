#!/bin/bash

set -ex

ceph health detail
ceph -s
ceph osd lspools
ceph osd pool ls
ceph osd pool ls|grep test-pool && ceph osd pool delete test-pool test-pool --yes-i-really-really-mean-it || echo "test-pool not existing"
ceph osd pool ls|grep pool-test && ceph osd pool delete pool-test pool-test --yes-i-really-really-mean-it || echo "pool-test not existing"
ceph osd pool create test-pool 8 8 replicated
ceph osd pool ls|grep test
ceph osd pool rename test-pool pool-test
ceph osd pool application enable pool-test rbd
ceph mon stat
ceph mon_status -f json-pretty
ceph mon dump
ceph quorum_status -f json-pretty
ceph osd stat
ceph osd tree
rados df
ceph df

echo "Result: OK"

set +ex


