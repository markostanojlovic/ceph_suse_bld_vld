#!/bin/bash
# This script is testing mount of NFS export with different mount options 
# USAGE:
# ./NFS_client_test.sh NFS_IP

set -ex

[[ -n $1 ]] && NFS_IP=$1

TIMEOUT=10   

MOUNTS=/tmp/mounts
##### mount options input file #####
echo "\
mount.nfs4 -o rw,hard,intr,noatime
mount.nfs4 -o rw,soft,timeo=20,noatime 
mount -t nfs 
mount -t nfs -o rw,sync 
mount.nfs4 " > $MOUNTS
####################################

openssl rand -base64 10000000 -out /tmp/random.txt # 13MB 
mount|grep '/mnt ' && sudo umount /mnt -f 
ping -q -c 3 $NFS_IP

while read mount_options
do
sudo timeout $TIMEOUT $mount_options ${NFS_IP}:/ /mnt
sudo timeout $TIMEOUT ls /mnt/cephfs
sudo timeout $TIMEOUT cp /tmp/random.txt /mnt/cephfs/nfs-ganesha_test_file_$(date +%H_%M_%S)
sudo timeout $TIMEOUT tail -n 1 /mnt/cephfs/nfs-ganesha_test_file_*
sudo timeout $TIMEOUT umount /mnt
done < $MOUNTS

echo 'Result: OK'

set +ex
