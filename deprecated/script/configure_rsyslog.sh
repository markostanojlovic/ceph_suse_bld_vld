# this needs to be done after each ceph restart - not permanently configured 
__ceph_daemon_logs_to_journal

# =====================================
# 3. rsyslog config (send logs from log file to journal)

# go to each minion, check if log file from the list exists and if so, add entry in rsyslog config
# ganesha
for i in $(_get_fqdn_from_pillar_role ganesha);
do
	node=${i%%\.*}
	ssh $i "sed -i 's/^#ganesha__//' /etc/rsyslog.conf"
done
# openattic
OA_fqdn=$(_get_fqdn_from_pillar_role openattic);
oa_node=${OA_fqdn%%\.*}
ssh $OA_fqdn "sed -i 's/^#openattic__//' /etc/rsyslog.conf"
# grafana and deepsea @MASTER
ssh $MASTER "sed -i 's/^#deepsea__//' /etc/rsyslog.conf"
ssh $MASTER "sed -i 's/^#grafana__//' /etc/rsyslog.conf"

# restart rsyslogd on each node
ssh $MASTER "salt '*' cmd.run 'systemctl restart rsyslog.service'"
