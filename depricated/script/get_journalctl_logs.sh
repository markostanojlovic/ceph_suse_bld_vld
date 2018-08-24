#!/bin/bash
# script to collect journalctl logs from the node
# run from node locally
# use: ./get_journalctl_logs.sh $START_DATE_TIME $END_DATE_TIME $SCRIPT_NAME
# $START_DATE_TIME - from when to start collecting logs
# $END_DATE_TIME - till when to collect logs
# $SCRIPT_NAME - $0 - name of the script during which time logs are collected
LIST_OF_JOURNAL_TAGS=/tmp/list_of_journal_tags
cat <<EOF > $LIST_OF_JOURNAL_TAGS
ceph
ceph-osd
ceph-mon
ceph-mgr
ceph-mds
lrbd
salt-minion
salt-master
radosgw
zypp_history
zypper_log
ganesha
openattic
grafana
deepsea
EOF
# which are active services locally on the node # not used due to better solution with journal tags
# ACTIVE_SERVICES=/tmp/active_services
# while read -r service;do systemctl|grep "${service}.*.service"|grep -v target|awk '{print $1}';done < $LIST_OF_SERVICES > $ACTIVE_SERVICES
START_DATE_TIME=${1} # FORMAT: "2017-11-07 14:00"
END_DATE_TIME=${2}
SCRIPT_NAME=$3
while read -r journal_identifier
do
	# get journalctl logs
	journalctl -p info -t $journal_identifier --since "$START_DATE_TIME" --until "$END_DATE_TIME" > /tmp/${journal_identifier}_${HOSTNAME}_${SCRIPT_NAME}_log
done < $LIST_OF_JOURNAL_TAGS
# get journal for all services, but only above warning
journalctl -p warning --since "$START_DATE_TIME" --until "$END_DATE_TIME" > /tmp/journal_err_log

# remove empty files
rm $(grep -ir "No entries" /tmp/*_log|tr ':' ' '|awk '{print $1}')
