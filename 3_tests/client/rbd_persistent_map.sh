#!/bin/bash

set -ex

POOL=rbd_pers
RBD_IMG=tst_rbd_img
# @admin:
ceph osd pool create $POOL 32 32
ceph osd pool application enable $POOL rbd
rbd -p $POOL ls|grep $RBD_IMG && rbd -p $POOL rm $RBD_IMG
rbd -p $POOL create $RBD_IMG --size 1G
# @client:
[[ -r /etc/ceph/ceph.client.admin.keyring ]] || exit 1 # requirement
rbd map ${POOL}/${RBD_IMG}
RBD_DEV=$(rbd showmapped|grep $RBD_IMG|awk '{print $5}')
sgdisk --largest-new=1 $RBD_DEV
mkfs.xfs ${RBD_DEV}p1 -f
rbd unmap $RBD_DEV
echo "${POOL}/${RBD_IMG} id=admin,keyring=/etc/ceph/ceph.client.admin.keyring"|tee -a /etc/ceph/rbdmap
systemctl enable rbdmap.service
systemctl start  rbdmap.service
systemctl status rbdmap.service
rbd showmapped|grep $RBD_IMG

set +ex
