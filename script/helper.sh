# Sourcing the helper functions commonly used in other scripts

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
