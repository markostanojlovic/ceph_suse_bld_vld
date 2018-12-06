#!/bin/bash

[[ -z $1 ]] && exit 1 || NUM=$1
[[ -z $2 ]] && exit 1 || NAME_BASE=$2

set -ex

(( r1=$NUM / 2 ))
(( r2=$NUM - $r1 ))

ceph osd crush add-bucket dc root
ceph osd crush add-bucket rack1 rack
ceph osd crush add-bucket rack2 rack
ceph osd crush move rack1 root=dc
ceph osd crush move rack2 root=dc

for (( i=1; i<=$r1; i++ )) 
do 
    ceph osd crush move ${NAME_BASE}$i rack=rack1
done

for (( j=$r2; j<=$NUM; j++ )) 
do 
    ceph osd crush move ${NAME_BASE}$j rack=rack2
done

ceph osd crush tree

echo "Result: OK"

set +ex

