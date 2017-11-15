# script for preparing VMs after they are created and OSD disks added
# and after the autoyast script has finished
# 	- adding hosts file
#	- install and configure salt minion
#	- install and configure salt master

cat <<EOF > /tmp/prepare_VM
#!/bin/bash
set -x
zypper ref
zypper in -y salt-minion
sed -i "/#master: salt/c\master: $MASTER" /etc/salt/minion
systemctl enable salt-minion.service;systemctl start salt-minion.service
sed -i "/server cz.pool.ntp.org iburst/c\server $MASTER iburst" /etc/ntp.conf
EOF

for (( NODE_NUMBER=1; NODE_NUMBER <=$VM_NUM; NODE_NUMBER++ ))
do
	# add hosts file entries to each VM
	scp /tmp/hosts_file ${VM_NAME_BASE}${NODE_NUMBER}:/tmp/
	ssh ${VM_NAME_BASE}${NODE_NUMBER} "cat /tmp/hosts_file >> /etc/hosts"
	# run the prepare script on the host
	ssh ${VM_NAME_BASE}${NODE_NUMBER} 'bash -s' < /tmp/prepare_VM
done

_run_script_on_remote_host $MASTER ${BASEDIR}/script/configure_salt_master.sh $MASTER $MASTER_IP
