#!/bin/bash
#
# Requirement: must be exec on admin node
# It's assumed that cluster has nodes 6 and 7 with only IGW roles 

set -ex

source src/helper.sh
source_cfg $@
LOG=$(setup_log_path $@)

# mount disk to a client server and configure multipath
ssh root@$CLIENT_NODE << OFSSH >> $LOG 2>&1
set -ex
systemctl status iscsid || echo
iSCSI_PORTAL=${NAME_BASE}6
iscsiadm -m discovery --type=st --portal=$iSCSI_PORTAL
result=$(iscsiadm -m discovery --type=st --portal=$iSCSI_PORTAL|tail -n 1)
target=iqn${result#*iqn}
iscsiadm -m node -n $target --login    
lsscsi
systemctl status multipathd || echo
multipath -d
multipath -v2 -l
systemctl start multipathd
systemctl status  multipathd
multipath -l
lsblk
dev_id=$(lsblk -l|grep mpath|awk '{print $1}'|uniq)
MAPPED_DEV=/dev/mapper/$dev_id
sgdisk --largest-new=1 ${MAPPED_DEV}
mkfs.xfs ${MAPPED_DEV}-part1 -f
mount ${MAPPED_DEV}-part1 /mnt
base64 /dev/urandom | head --bytes=9MB > /mnt/file.txt
echo Result: OK
set +ex
OFSSH

# TODO simulate writing and failure of one node during the io operations

echo "Result: OK" >> $LOG 2>&1

set +ex
