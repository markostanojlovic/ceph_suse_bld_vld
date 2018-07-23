# Helper functions that are shared among TC scripts

function _get_osd_disk_dev {
    disk=$(mount|grep ceph|awk -F '/' '{print $3}'|head -c 3)
    echo $disk
}

function _get_osd_id {
    osd_id=$(mount|grep ceph|awk -F 'ceph-' '{print $2}'|awk -F 'type' '{print $1}'|head -n 1|tr -d ' ')
    echo $osd_id
}
