#!/bin/bash

[[ -z $1 ]] && exit 1 || POOl_NAME=$1

set -ex 

ceph osd pool create $POOl_NAME 8 8 replicated
ceph osd pool application enable $POOl_NAME rbd
ceph osd pool set $POOl_NAME compression_algorithm zstd
ceph osd pool set $POOl_NAME compression_mode force 

echo "Result: OK"

set +ex
