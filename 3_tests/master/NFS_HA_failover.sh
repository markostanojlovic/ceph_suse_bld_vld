#!/bin/bash

function _get_fqdn_from_salt_grain_key {
  salt -C G@${1}:* grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '
}

function _get_fqdn_from_pillar_role {
  salt -C I@roles:${1} grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '
}

set -ex

PRIMARY=$(_get_fqdn_from_salt_grain_key NFS_HA_master|tail -n 1)
echo "Primary nfs-ganesha node is : " $PRIMARY
SECONDARY=$(_get_fqdn_from_pillar_role ganesha|grep -v $PRIMARY)
echo "Secondary nfs-ganesha node is : " $SECONDARY
CURR=$(salt ${PRIMARY} cmd.run "crm status"|grep ganesha-ip|awk '{print $4}')
echo 'Current ganesha-ip node is :' $CURR
if [[ $CURR == $PRIMARY ]]; then
  failover_node=$SECONDARY
else
  failover_node=$PRIMARY
fi
salt ${PRIMARY} cmd.run "crm status"
salt ${PRIMARY} cmd.run "crm resource migrate ganesha-ip $failover_node"
sleep 30 # adjustment period
salt ${PRIMARY} cmd.run "crm status"
salt ${PRIMARY} cmd.run "crm status" | grep ganesha-ip | grep $failover_node

echo "Result: OK"

set +ex
