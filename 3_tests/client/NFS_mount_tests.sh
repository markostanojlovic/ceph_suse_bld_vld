#!/bin/bash
# This script is testing mount of NFS export with different mount options 
# USAGE:
# ./NFS_client_test.sh NFS_IP

set -e

[[ -n $1 ]] && NFS_IP=$1 || (echo ERROR: Missing NFS IP; exit 1)
timeout_limit=10   
MOUNTS=/tmp/mounts
##### mount options input file #####
echo "\
mount.nfs4 -o rw,hard,intr,noatime
mount.nfs4 -o rw,soft,timeo=20,noatime 
mount -t nfs 
mount -t nfs -o rw,sync 
mount.nfs4 " > $MOUNTS
####################################
mount_target="${NFS_IP}:/ /mnt"
openssl rand -base64 10000000 -out /tmp/random.txt

function test_command_for_timeout {
	command_to_test=$1
	timeout $timeout_limit $command_to_test
	timeout_rc=$?
	if [[ $timeout_rc == 0 ]]
		then
		echo "INFO: command: [ $command_to_test ] finished OK" 
	else
		echo "ERROR: command: [ $command_to_test ] timed out after $timeout_limit seconds"; exit 1 
    fi
}

mount|grep mnt && umount /mnt -f 
# test ping
ping -q -c 3 $NFS_IP|grep " 0% packet loss" || ( echo "PING status: *** KO ***";exit 1 )
echo "PING status: OK " 
# TESTING
while read mount_options
do
sleep 60
test_command_for_timeout "$mount_options $mount_target"
test_command_for_timeout "ls /mnt/cephfs"
test_command_for_timeout "cp /tmp/random.txt /mnt/cephfs/nfs-ganesha_test_file_$(date +%H_%M_%S)"
test_command_for_timeout "tail -n 1 /mnt/cephfs/nfs-ganesha_test_file_*"
test_command_for_timeout 'umount /mnt'
done < $MOUNTS

echo 'Result: OK'

set +e
