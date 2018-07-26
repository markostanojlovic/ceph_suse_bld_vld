#!/bin/bash

set -ex

if [[ -z $1 ]]
then
  echo "Error: NFS_HA_IP input argument missing."
  exit 1
else
  NFS_HA_IP=$1
fi

#######################################################################
function _get_fqdn_from_salt_grain_key {
  salt -C G@${1}:* grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '
}

function _get_fqdn_from_pillar_role {
  salt -C I@roles:${1} grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '
}

function ha_ganesha_ip_failover {
  PRIMARY=$(_get_fqdn_from_salt_grain_key NFS_HA_master|tail -n 1)
  #PRIM=${PRIMARY%%\.*}
  echo "Primary nfs-ganesha node is : " $PRIMARY
  SECONDARY=$(_get_fqdn_from_pillar_role ganesha|grep -v $PRIMARY)
  #SEC=${SECONDARY%%\.*}
  echo "Secondary nfs-ganesha node is : " $SECONDARY
  CURR=$(salt ${PRIMARY} cmd.run "crm status"|grep ganesha-ip|awk '{print $4}')
  echo 'Current ganesha-ip node is :' $CURR
  if [[ $CURR == $PRIMARY ]]; then
    failover_node=$SECONDARY
  else
    failover_node=$PRIMARY
  fi
  salt ${PRIMARY} cmd.run "crm resource migrate ganesha-ip $failover_node"
  sleep 3 # adjustment period
}

function clear_NFS_HA {
  PRIMARY=$(_get_fqdn_from_salt_grain_key NFS_HA_master)
  PRIM=${PRIMARY%%\.*}
  # crm resource show
  salt ${PRIM} cmd.run "crm resource stop ganesha-ip"
  salt ${PRIM} cmd.run "crm configure delete ganesha-ip"
  # TODO remove servers from cluster - destroy cluster
  # crm resource cleanup nfs-ganesha-server # only clears logs
  salt -C 'I@roles:ganesha' cmd.run "systemctl stop hawk;systemctl stop pacemaker"
  salt -C 'I@roles:ganesha' cmd.run "zypper rm -y ha-cluster-bootstrap hawk pacemaker"
}

#######################################################################

# set NFS HA IP
salt -C 'I@roles:ganesha' grains.setval NFS_HA_IP $NFS_HA_IP

# Disable NFS Ganesha service 
salt -C 'I@roles:ganesha' cmd.run 'systemctl disable nfs-ganesha.service'

# HA REPO setup 
salt -C 'I@roles:ganesha' cmd.run 'wget -q -P /tmp/ http://mirror.suse.cz/install/SLE-12-HA-GM/SLE-12-HA-DVD-x86_64-GM-CD1.iso'
salt -C 'I@roles:ganesha' cmd.run 'zypper rr ha-1 || echo "no ha-1 repo"'
salt -C 'I@roles:ganesha' cmd.run 'zypper ar -t yast2 -c -f "iso:/?iso=/tmp/SLE-12-HA-DVD-x86_64-GM-CD1.iso" ha-1'
salt -C 'I@roles:ganesha' cmd.run 'zypper in -y ha-cluster-bootstrap'

# Set NFS HA primary and secondary node
PRIMAR=$(_get_fqdn_from_pillar_role ganesha|head -n 1)
salt $PRIMAR grains.setval NFS_HA_master True
SECOND=$(_get_fqdn_from_pillar_role ganesha|grep -v $PRIMAR)

# NFS HA cluster bootstrap
### establish passwordless ssh access to HA nodes
HANODE1=$PRIMAR
HANODE2=$SECOND
salt -C 'I@roles:ganesha' cmd.run "sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config"
salt -L ${HANODE1},${HANODE2} cmd.run 'rm -f /root/.ssh/id_rsa*;ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa'
PUBKEY_NODE1=$(salt $HANODE1 cmd.run 'cat /root/.ssh/id_rsa.pub' --out yaml|sed 's/.* ssh-rsa/ssh-rsa/g')
PUBKEY_NODE2=$(salt $HANODE2 cmd.run 'cat /root/.ssh/id_rsa.pub' --out yaml|sed 's/.* ssh-rsa/ssh-rsa/g')
## configure cluster
salt $HANODE1 cmd.run "echo $PUBKEY_NODE2 >> ~/.ssh/authorized_keys"
salt $HANODE2 cmd.run "echo $PUBKEY_NODE1 >> ~/.ssh/authorized_keys"
salt ${PRIMAR} cmd.run 'ha-cluster-init -y'
salt ${SECOND} cmd.run "ha-cluster-join -y -c $HANODE1 csync2"
salt ${SECOND} cmd.run "ha-cluster-join -y -c $HANODE1 ssh_merge"
salt ${SECOND} cmd.run "ha-cluster-join -y -c $HANODE1 cluster"
salt ${PRIMAR} cmd.run 'crm configure primitive nfs-ganesha-server systemd:nfs-ganesha op monitor interval=30s'
salt ${PRIMAR} cmd.run 'crm configure clone nfs-ganesha-clone nfs-ganesha-server meta interleave=true'
salt ${PRIMAR} cmd.run "crm configure primitive ganesha-ip IPaddr2 params ip=${NFS_HA_IP} cidr_netmask=24 nic=eth0 op monitor interval=10 timeout=20"
salt ${PRIMAR} cmd.run "crm configure commit"
salt ${PRIMAR} cmd.run "crm status"
salt ${PRIMAR} cmd.run "crm resource cleanup nfs-ganesha-server"
salt ${PRIMAR} cmd.run "crm status"

# NFS client test TODO

# HA failover
ha_ganesha_ip_failover

# NFS client test TODO

# HA failback
ha_ganesha_ip_failover

# NFS client test TODO

# HA cleanup TODO


set +ex
