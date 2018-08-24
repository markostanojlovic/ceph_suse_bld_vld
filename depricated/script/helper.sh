# Sourcing the helper functions commonly used in other scripts

function _test_command_for_timeout {
  timeout_limit=$1
  command_to_test=$2
  timeout $timeout_limit $command_to_test
  timeout_rc=$?
  if [[ $timeout_rc == 0 ]];then
    	echo "INFO: command: [ $command_to_test ] finished OK"
    else
    	echo "ERROR: command: [ $command_to_test ] timed out after $timeout_limit seconds"; echo 'Result: NOT_OK';exit 1
  fi
}

function _run_script_on_remote_host {
	# USAGE: _run_script_on_remote_host HOST SCRIPT_PATH SCRIPT_OTHER_ARGUMENTS
	REMOTE_HOST=$1
	SCRIPT_NAME=${2##*/}
	LOG_FILE=${BASEDIR}/log/${LOG_DIR}/${SCRIPT_NAME}.log_$(date +%Y_%m_%d_%H_%M_%S)
	scp $2 $REMOTE_HOST:/tmp/$SCRIPT_NAME
	ssh $REMOTE_HOST "chmod +x /tmp/$SCRIPT_NAME"
	shift;shift
	ssh $REMOTE_HOST "/tmp/$SCRIPT_NAME $@" > $LOG_FILE 2>&1
	cat $LOG_FILE
}

function _run_command_on_remote_host {
	# USAGE: _run_command_on_remote_host HOST "COMMAND"
	REMOTE_HOST=$1
	COMMAND=$2
  LOG_FILE=${BASEDIR}/log/${LOG_DIR}/log_remote_exe_$(date +%Y_%m_%d_%H_%M_%S)
	ssh $REMOTE_HOST "$COMMAND" > $LOG_FILE 2>&1
	cat $LOG_FILE
}

function _get_igw_portals {
	IGW_NODE=$(_get_fqdn_from_pillar_role igw|head -n 1)
	ssh root@$MASTER "salt $IGW_NODE cmd.run \"targetcli ls iscsi\"|tr -d ' |o-'|egrep \"^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}.*\"|sed 's/:.*//'"
}

function _wait_autoyast_script_completion {
sleep 120
# Waiting for autoyast script to be completed
TIMEOUT_COUNTER=1
for (( i=1; i <=$VM_NUM; i++ ))
do
	while ! ssh ${VM_NAME_BASE}${i} "tail -n 1 /tmp/initscript.log"|grep 'SCRIPT DONE' >/dev/null
	do
		sleep 5
		echo "Autoyast init script on host ${VM_NAME_BASE}${i} not done..."
		let TIMEOUT_COUNTER=$TIMEOUT_COUNTER+1
		if [[ $TIMEOUT_COUNTER -gt 300 ]]
		then
			echo "TIMEOUT!"
			exit 1
		fi
	done
	echo "Autoyast init script on host ${VM_NAME_BASE}${i} FINISHED."
done
}

function _wait_autoyast_script_completion_for_host {
sleep 120
# Waiting for autoyast script to be completed
HOST_TO_WAIT=$1
TIMEOUT_COUNTER=1
while ! ssh ${HOST_TO_WAIT} "tail -n 1 /tmp/initscript.log"|grep 'SCRIPT DONE' >/dev/null
do
	sleep 5
	let TIMEOUT_COUNTER=$TIMEOUT_COUNTER+1
	if [[ $TIMEOUT_COUNTER -gt 300 ]]; then
		echo "TIMEOUT!"; exit 1
	fi
done
echo "Autoyast init script on host ${HOST_TO_WAIT} FINISHED."
}

function _wait_for_host_booted {
	REMOTE_HOST=$1
	TIMEOUT_COUNTER=1
	TIMEOUT_LIMIT=60 	# one iteration is around 5s
	while ! ssh $REMOTE_HOST 'hostname;date' 2>/dev/null|grep $REMOTE_HOST
	do
		sleep 3
		let TIMEOUT_COUNTER=$TIMEOUT_COUNTER+1
		if [[ $TIMEOUT_COUNTER -gt $TIMEOUT_LIMIT ]]
		then
			echo "Server boot TIMEOUT!"
			exit 1
		fi
	done
}

function _wait_for_all_VMs_up {
for (( i=1; i <=$VM_NUM; i++ ))
do
	_wait_for_host_booted ${VM_NAME_BASE}${i}
done
}

function _wait_ceph_health_OK {
	echo "Checking SES cluster health..."
	TIMEOUT=$CLUSTER_HEALTH_OK_TIMEOUT
	TIMER=0
	while sleep 5
	do
		if [[ $TIMER -gt $TIMEOUT ]] ;then echo "HEALTH_OK TIMEOUT! Check cluster health. "; break;fi
		if [[ "$(ssh $MASTER "ceph health")" == "HEALTH_OK" ]] ;then echo "HEALTH_OK";break;fi
		(( TIMER+=5 ))
	done
}

function __ceph_daemon_logs_to_journal {
	# send logs directly to journal
	# @ MASTER: set all daemons logging : ceph daemon __daemon_name__ config set log_to_syslog true
	# valid daemon types: mon, osd, mds, mgr
	for i in $(_get_fqdn_from_pillar_role mon);do node=${i%%\.*};ssh $i "ceph daemon mon.${node} config set log_to_syslog true";done
	for i in $(_get_fqdn_from_pillar_role mgr);do node=${i%%\.*};ssh $i "ceph daemon mgr.${node} config set log_to_syslog true";done
	for i in $(_get_fqdn_from_pillar_role mds);do node=${i%%\.*};ssh $i "ceph daemon mds.${node} config set log_to_syslog true";done
	for i in $(_get_fqdn_from_pillar_role storage)
	do
		node=${i%%\.*}
		OSD_LIST=$(ssh $MASTER "ceph osd crush ls $node")
		for osd in $OSD_LIST;do ssh $i "ceph daemon $osd config set log_to_syslog true";done
	done
}

function _is_host_reachable {
	ssh $1 hostname && echo true || echo false
}


function _get_salt_grain_value {
	# input argument is salt grain key
	ssh root@$MASTER "salt -C G@${1}:* grains.item $1 --out=yaml|grep $1|sed \"s/${1}: //g\"|tr -d ' '"
}

function _get_fqdn_from_salt_grain_key {
	# input argument is salt grain key
	ssh root@$MASTER "salt -C G@${1}:* grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '"
}

function _get_fqdn_from_pillar_role {
	# input argument is salt grain key
	ssh root@$MASTER "salt -C I@roles:${1} grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '"
}

function _get_salt_master_fqdn {
	ssh root@$MASTER "salt-call grains.item master --out yaml |grep master|awk -F ':' '{print \$2}'|tr -d ' '"
}

function ha_repo_setup {
        salt -C 'I@roles:ganesha' cmd.run 'wget -P /tmp/ http://mirror.suse.cz/install/SLE-12-HA-GM/SLE-12-HA-DVD-x86_64-GM-CD1.iso'
        salt -C 'I@roles:ganesha' cmd.run 'zypper ar -t yast2 -c -f "iso:/?iso=/tmp/SLE-12-HA-DVD-x86_64-GM-CD1.iso" ha-1'
        salt -C 'I@roles:ganesha' cmd.run 'zypper in -y ha-cluster-bootstrap'
}
function set_NFS_HA_primary_node {
  # setting one of ganesha nodes to be HA primary node
  NFS_NODE=$(_get_fqdn_from_pillar_role ganesha|head -n 1)
  salt $NFS_NODE grains.setval ceph_ganesha_HA_master_node True
}
function nfs_ganesha_disable_service {
        salt -C 'I@roles:ganesha' cmd.run 'systemctl disable nfs-ganesha.service'
}
function nfs_ganesha_restart_service {
        salt -C 'I@roles:ganesha' cmd.run 'systemctl restart nfs-ganesha'
}
function set_NFS_HA_IP {
        HA_GANESHA_IP=$1
        echo "NFS HA IP is : " $HA_GANESHA_IP
        salt -C 'I@roles:ganesha' grains.setval NFS_HA_IP $HA_GANESHA_IP
}
function get_NFS_HA_IP {
        echo $(_get_salt_grain_value NFS_HA_IP|tail -n 1)
}
function nfs_ha_cluster_bootstrap {
        NFS_GANESHA_primary_node=$(_get_fqdn_from_salt_grain_key ceph_ganesha_HA_master_node)
        NFS_GANESHA_secondary_node=$(_get_fqdn_from_pillar_role ganesha|grep -v $NFS_GANESHA_primary_node)

        # establish passwordless ssh access to HA nodes
        MINION_HA_NODE_1=$NFS_GANESHA_primary_node
        MINION_HA_NODE_2=$NFS_GANESHA_secondary_node
        salt -C 'I@roles:ganesha' cmd.run "sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config"
        salt $MINION_HA_NODE_1\* cmd.run 'ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa'
        salt $MINION_HA_NODE_2\* cmd.run 'ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa'
        PUB_KEY_HA_NODE_1=$(salt $MINION_HA_NODE_1 cmd.run 'cat /root/.ssh/id_rsa.pub' --out yaml|sed 's/.* ssh-rsa/ssh-rsa/g')
        PUB_KEY_HA_NODE_2=$(salt $MINION_HA_NODE_2 cmd.run 'cat /root/.ssh/id_rsa.pub' --out yaml|sed 's/.* ssh-rsa/ssh-rsa/g')
        salt $MINION_HA_NODE_1 cmd.run "echo $PUB_KEY_HA_NODE_2 >> ~/.ssh/authorized_keys"
        salt $MINION_HA_NODE_2 cmd.run "echo $PUB_KEY_HA_NODE_1 >> ~/.ssh/authorized_keys"

        # configure cluster
        HA_GANESHA_IP=$(get_NFS_HA_IP)
        salt ${NFS_GANESHA_primary_node} cmd.run 'ha-cluster-init -y'
        salt ${NFS_GANESHA_secondary_node} cmd.run "ha-cluster-join -y -c $MINION_HA_NODE_1 csync2"
        salt ${NFS_GANESHA_secondary_node} cmd.run "ha-cluster-join -y -c $MINION_HA_NODE_1 ssh_merge"
        salt ${NFS_GANESHA_secondary_node} cmd.run "ha-cluster-join -y -c $MINION_HA_NODE_1 cluster"
        salt ${NFS_GANESHA_primary_node} cmd.run 'crm configure primitive nfs-ganesha-server systemd:nfs-ganesha op monitor interval=30s'
        salt ${NFS_GANESHA_primary_node} cmd.run 'crm configure clone nfs-ganesha-clone nfs-ganesha-server meta interleave=true'
        salt ${NFS_GANESHA_primary_node} cmd.run "crm configure primitive ganesha-ip IPaddr2 params ip=${HA_GANESHA_IP} cidr_netmask=24 nic=eth0 op monitor interval=10 timeout=20"
        salt ${NFS_GANESHA_primary_node} cmd.run "crm configure commit"
        salt ${NFS_GANESHA_primary_node} cmd.run "crm status"
        salt ${NFS_GANESHA_primary_node} cmd.run "crm resource cleanup nfs-ganesha-server"
        salt ${NFS_GANESHA_primary_node} cmd.run "crm status"
}
function ha_ganesha_ip_failover {
        NFS_GANESHA_primary_node_fqdn=$(_get_fqdn_from_salt_grain_key ceph_ganesha_HA_master_node)
        NFS_GANESHA_primary_node=${NFS_GANESHA_primary_node_fqdn%%\.*}
        echo "Primary nfs-ganesha node is : " $NFS_GANESHA_primary_node
        NFS_GANESHA_secondary_node_fqdn=$(_get_fqdn_from_pillar_role ganesha|grep -v $NFS_GANESHA_primary_node)
        NFS_GANESHA_secondary_node=${NFS_GANESHA_secondary_node_fqdn%%\.*}
        echo "Secondary nfs-ganesha node is : " $NFS_GANESHA_secondary_node
        current_ganesha_ip_node=$(salt ${NFS_GANESHA_primary_node_fqdn} cmd.run "crm status"|grep ganesha-ip|awk '{print $4}')
        echo 'Current ganesha-ip node is :' $current_ganesha_ip_node
        if [[ $current_ganesha_ip_node == $NFS_GANESHA_primary_node ]]; then
                failover_node=$NFS_GANESHA_secondary_node
        else
                failover_node=$NFS_GANESHA_primary_node
        fi
        salt ${NFS_GANESHA_primary_node_fqdn} cmd.run "crm resource migrate ganesha-ip $failover_node"
        sleep 3 # adjustment period
}
function clear_NFS_HA {
  NFS_GANESHA_primary_node_fqdn=$(_get_fqdn_from_salt_grain_key ceph_ganesha_HA_master_node)
  NFS_GANESHA_primary_node=${NFS_GANESHA_primary_node_fqdn%%\.*}
  # crm resource show
  salt ${NFS_GANESHA_primary_node} cmd.run "crm resource stop ganesha-ip"
  salt ${NFS_GANESHA_primary_node} cmd.run "crm configure delete ganesha-ip"
  # crm resource cleanup nfs-ganesha-server # only clears logs
  salt -C 'I@roles:ganesha' cmd.run "systemctl stop hawk;systemctl stop pacemaker"
  salt -C 'I@roles:ganesha' cmd.run "zypper rm -y ha-cluster-bootstrap hawk pacemaker"
}
