#!/bin/bash
# DO NOT RUN THE SCRIPT,
# ONLY run this commands MANUALLY on salt master node

TC_VM_NAME=ses_wal_db_tc
DOMAIN=qatest

# remove node from salt-master auth
salt-key -d ${TC_VM_NAME}.${DOMAIN} -y
# destroy node from cluster with OSDs
rm $(find /srv/ -name "${TC_VM_NAME}.${DOMAIN}*")
salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.5

# if OSDs are not removed by stage 5, then :
# to remove OSDs manually with DS
salt-run disengage.safety
for i in $(ceph osd crush ls $TC_VM_NAME|sed 's/osd.//g')
do
  salt-run remove.osd $i
done

# ro remove OSDs manually manually, if DS remove.osd runner is not working
for i in $(ceph osd tree down|grep -o "osd."...);do
  ceph osd crush remove $i
  ceph auth del $i
  ceph osd rm $i
done

# removing host from a crush map
ceph osd getcrushmap -o /tmp/crushmap
crushtool -d /tmp/crushmap -o crush_map
cat crush_map
sed -i "/item $TC_VM_NAME weight/d" crush_map
sed -i "/${TC_VM_NAME}/,/}/ d" crush_map
cat crush_map|grep ${TC_VM_NAME} || echo "Good, CRUSH MAP is clear."
crushtool -c crush_map -o /tmp/crushmap
ceph osd setcrushmap -i /tmp/crushmap
ceph osd tree|grep ${TC_VM_NAME} || echo "Good, CRUSH MAP is clear. Confirmed also by: ceph osd tree"
