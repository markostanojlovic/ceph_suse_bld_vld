#!/bin/bash
#
# Requirement: node where script it executed has to be storage and admin node 

set -ex

# TODO check if node is both storage and admin node 

source /tmp/node_helper.sh
ceph osd tree
osd_id=$(_get_osd_id)
disk=$(_get_osd_disk_dev $osd_id)
device=$(_get_osd_disk_device $osd_id)
ceph osd out osd.${osd_id}
ceph osd tree
ceph -s
systemctl stop ceph-osd@${osd_id}.service
ceph osd crush remove osd.${osd_id}
ceph auth del osd.${osd_id}
ceph auth ls|grep osd.${osd_id} || echo "OSD not in auth list"
ceph osd rm osd.${osd_id}
mount|grep ceph
umount /var/lib/ceph/osd/ceph-${osd_id}
# ceph-volume lvm zap /dev/${disk} --destroy
ceph-volume lvm zap $device --destroy
# sgdisk --zap-all /dev/${disk}
# sgdisk --clear --mbrtogpt /dev/${disk}
lsblk

echo "Result: OK"

set +ex


