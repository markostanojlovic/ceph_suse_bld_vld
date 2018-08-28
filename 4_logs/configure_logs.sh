#!/bin/bash
# 
# Configure log collecting

if [[ -z $1 ]]
then
  echo "ERROR: Argument missing. USAGE example: ./run.sh cfg/maiax86_64.cfg"
  exit 1
else
  source $1
fi

# Add rsyslog config entries to all nodes
for (( i=1; i <= $VM_NUM; i++ ))
do
    ssh root@${NAME_BASE}${i} <<EOSSH
# CONFIG journal and rsyslog
mkdir -p /var/log/journal
sed -i '/Storage/c\Storage=persistent' /etc/systemd/journald.conf
systemctl restart systemd-journald.service
cat<<EOF >>/etc/rsyslog.conf
# sending file logs to journal
module(load="imfile" PollingInterval="5")
module(load="omjournal") # output module for journal
# LIST OF FILES
input(type="imfile" File="/var/log/ceph/ceph.log" Tag="ceph" Severity="info" Facility="local7" ruleset="writeToJournal")
input(type="imfile" File="/var/log/zypp/history" Tag="zypp_history" Severity="info" Facility="local7" ruleset="writeToJournal")
input(type="imfile" File="/var/log/zypper.log" Tag="zypper_log" Severity="info" Facility="local7" ruleset="writeToJournal")
#ganesha__input(type="imfile" File="/var/log/ganesha/ganesha.log" Tag="ganesha" Severity="info" Facility="local7" ruleset="writeToJournal")
#openattic__input(type="imfile" File="/var/log/openattic/openattic.log" Tag="openattic" Severity="info" Facility="local7" ruleset="writeToJournal")
#deepsea__input(type="imfile" File="/var/log/deepsea.log" Tag="deepsea" Severity="info" Facility="local7" ruleset="writeToJournal")
#grafana__input(type="imfile" File="/var/log/grafana/grafana.log" Tag="grafana" Severity="info" Facility="local7" ruleset="writeToJournal")
ruleset(name="writeToJournal") {
        action(type="omjournal")
}
EOF
systemctl restart rsyslog.service
EOSSH
done

# go to each minion, check if log file from the list exists and if so, uncomment entry in rsyslog config
ssh root@$MASTER <<EOSSH
set -x
source /tmp/node_helper.sh
# ganesha
for i in \$(_get_fqdn_from_pillar_role ganesha);
do
	salt \$i cmd.run "sed -i 's/^#ganesha__//' /etc/rsyslog.conf"
done
# openattic
OA_fqdn=\$(_get_fqdn_from_pillar_role openattic);
salt \$OA_fqdn cmd.run "sed -i 's/^#openattic__//' /etc/rsyslog.conf"
# grafana and deepsea @MASTER
sed -i 's/^#deepsea__//' /etc/rsyslog.conf
sed -i 's/^#grafana__//' /etc/rsyslog.conf
set +x
EOSSH

# send logs directly to journal
# set all daemons logging : ceph daemon __daemon_name__ config set log_to_syslog true
# valid daemon types: mon, osd, mds, mgr
# this is not permanent, after every ceph restart, needs to be configured again
cat <<EOF > /tmp/ceph_deamon_rsyslog.sh
source /tmp/node_helper.sh
for i in \$(_get_fqdn_from_pillar_role mon);do node=\${i%%\.*};salt \$i cmd.run "ceph daemon mon.\${node} config set log_to_syslog true";done
for i in \$(_get_fqdn_from_pillar_role mgr);do node=\${i%%\.*};salt \$i cmd.run "ceph daemon mgr.\${node} config set log_to_syslog true";done
for i in \$(_get_fqdn_from_pillar_role mds);do node=\${i%%\.*};salt \$i cmd.run "ceph daemon mds.\${node} config set log_to_syslog true";done
for i in \$(_get_fqdn_from_pillar_role storage)
do
	node=\${i%%\.*}
	OSD_LIST=\$(ceph osd crush ls \$node)
	for osd in \$OSD_LIST;do salt \$i cmd.run "ceph daemon \$osd config set log_to_syslog true";done
done
EOF
ssh root@$MASTER 'bash -sx' < /tmp/ceph_deamon_rsyslog.sh

# restart rsyslogd on each node
ssh root@$MASTER "salt '*' cmd.run 'systemctl restart rsyslog.service'"


