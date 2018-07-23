# Helper functions that are shared among TC scripts
# This helper functions can work on master and admin node, some functions are only dedicated for master
# Scipt needs to be copied to master node before executing 

function _get_osd_disk_dev {
    disk=$(mount|grep ceph|awk -F '/' '{print $3}'|head -c 3)
    echo $disk
}

function _get_osd_id {
    osd_id=$(mount|grep ceph|awk -F 'ceph-' '{print $2}'|awk -F 'type' '{print $1}'|head -n 1|tr -d ' ')
    echo $osd_id
}

function _get_obj_map_osd_id {
    obj_name=$1
    osd_id=$(ceph osd map EC_rbd_pool $obj_name | awk -F "up" '{print $2}'|awk -F ',' '{print $2}')
    echo $osd_id
}

# only @master
function _get_fqdn_from_pillar_role {
        salt -C I@roles:${1} grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '
}

