#!/bin/bash
# Script for testing ceph clients on a non-cluster node:
# - igw (iSCSI)
# - cephfs
# - NFS
# - RBD
# - RGW

# README:
# 	- *** ONLY WORKING FOR SLES 12 SP3 CLIENTS ***
# 	- Run as root from testing host
# 	- ssh paswrodless access to client server from testing host
# USAGE:
# ./ses_qa_scripts/clients.sh client_host_name_or_ip

source config/CONFIG
set -x

REMOTE_HOST_IP=$CLIENT_NODE
if [[ $(_is_host_reachable $REMOTE_HOST_IP) == false ]];then
	echo "Error: Host $REMOTE_HOST_IP not reachable!"
	exit
fi

# install ceph pkgs
ssh root@$REMOTE_HOST_IP 'zypper in -y librbd1 ceph-common open-iscsi;zypper se librbd1 ceph-common open-iscsi'

############
# igw
############
iSCSI_PORTAL=$(_get_fqdn_from_pillar_role igw)
for portal in $iSCSI_PORTAL
do
	_run_script_on_remote_host $REMOTE_HOST_IP ${BASEDIR}/script/client/igw_client_test.sh $portal
done

############
# cephFS
############
CEPHFS_IP=$(_get_fqdn_from_pillar_role mds)
CLIENT_ADMIN_KEY=$(ssh root@$MASTER "ceph auth list 2>/dev/null"|grep -A 1 client.admin|grep key|sed 's/key: //'|tr -d '\t')
for host in $CEPHFS_IP
do
	_run_script_on_remote_host $REMOTE_HOST_IP ${BASEDIR}/script/client/cephFS_client_test.sh $host $CLIENT_ADMIN_KEY
done

############
# NFS
############
NFS_IP=$(_get_fqdn_from_pillar_role ganesha)
for host in $NFS_IP
do
	_run_script_on_remote_host $REMOTE_HOST_IP ${BASEDIR}/script/client/nfs_client_test.sh $host
done

############
# RBD
############
scp root@$MASTER:/etc/ceph/ceph.conf /tmp/
scp /tmp/ceph.conf root@$REMOTE_HOST_IP:/etc/ceph/
scp root@$MASTER:/etc/ceph/ceph.client.admin.keyring /tmp/
scp /tmp/ceph.client.admin.keyring root@$REMOTE_HOST_IP:/etc/ceph/
RBD_POOL=rbd-disks
ssh root@$MASTER "ceph osd pool create $RBD_POOL 8 8"
ssh root@$MASTER "ceph osd pool application enable $RBD_POOL rbd"
_run_script_on_remote_host $REMOTE_HOST_IP ${BASEDIR}/script/client/rbd_client_test.sh $RBD_POOL

############
# RGW
############
RGW_HOSTS=$(_get_fqdn_from_pillar_role rgw)
for host in $RGW_HOSTS
do
	TCP_PORT=$(ssh root@$MASTER "salt $host cmd.run 'ss -n -l -p '"|grep tcp|grep radosgw|awk '{print $5}'|tr -d '*:')
	_run_script_on_remote_host $REMOTE_HOST_IP ${BASEDIR}/script/client/rgw_client_test.sh $host $TCP_PORT
done
