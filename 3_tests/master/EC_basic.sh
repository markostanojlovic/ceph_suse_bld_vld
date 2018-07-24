#!/bin/bash
#
# Requirement: script needs to be exec on master node 

set -ex

source /tmp/node_helper.sh

# Preparation: delete pool and check if EC-profile already exists  
ceph osd pool delete EC_rbd_pool EC_rbd_pool --yes-i-really-really-mean-it
ceph osd erasure-code-profile rm EC-profile

ceph osd erasure-code-profile ls
ceph osd erasure-code-profile set EC-profile
ceph osd erasure-code-profile set EC-profile crush-failure-domain=osd k=4 m=2 --force
ceph osd erasure-code-profile get EC-profile
ceph osd pool create EC_rbd_pool 8 8  erasure EC-profile
ceph osd pool application enable EC_rbd_pool rbd
base64 /dev/urandom | head --bytes=4MB > /tmp/4MB.random.txt.file
rados -p EC_rbd_pool put object.1 /tmp/4MB.random.txt.file
rados -p EC_rbd_pool ls
ceph osd map EC_rbd_pool object.1
id_of_osd_to_brake=$(_get_obj_map_osd_id object.1)
ceph osd out osd.${id_of_osd_to_brake}
ceph osd map EC_rbd_pool object.1
rados -p EC_rbd_pool get object.1 /tmp/4MB.random.txt.file.after
tail /tmp/4MB.random.txt.file.after
ceph osd in osd.${id_of_osd_to_brake}
ceph osd tree

echo "Result: OK"

set +ex


