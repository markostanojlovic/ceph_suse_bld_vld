#!/bin/bash

set -ex

iSCSI_PORTAL=$1
# checking and installing open-iscsi package
rpm -qa|grep open-iscsi || zypper in -y open-iscsi
systemctl enable iscsid;systemctl start iscsid;systemctl status iscsid
systemctl stop multipathd;systemctl disable multipathd 	# stop multipath if started
partprobe
iscsiadm -m node --logoutall=all || echo
rm -rf /etc/iscsi/nodes/* || echo "Empty dir..."
rm -rf /etc/iscsi/send_targets/* || echo "Empty dir..."
iscsiadm -m discovery --type=st --portal=$iSCSI_PORTAL
result=$(iscsiadm -m discovery --type=st --portal=$iSCSI_PORTAL|tail -n 1);target=iqn${result#*iqn};echo $target
iscsiadm -m node -n $target --login
sleep 1
iscsiadm -m session -o show
NEW_DISKS=$(for disk in $(find /dev/disk/ -name "*iscsi*");do ls -la $disk|grep -o [a-z][a-z][a-z]$;done);echo $new_disks
for new_disk in $NEW_DISKS
do
	echo "Checking disk " $new_disk
	# check if the disk is already partitioned
	blkid /dev/$new_disk || ( sgdisk --largest-new=1 /dev/$new_disk; mkfs.xfs /dev/${new_disk}1 -f )
	mount|grep mnt && umount /mnt -f
	mount /dev/${new_disk}1 /mnt
	ls -la /mnt
	openssl rand -base64 -out /mnt/igw_random.txt 10000000
	tail /mnt/igw_random.txt
	umount /mnt
	partprobe
done

echo "Result: OK"

set +ex 
