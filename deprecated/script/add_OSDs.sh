# Script for creating OSD disks for Ceph cluster and attaching the disks to cluster VMs
set -ex
# Input argument is number of VMs and their name base
VM_NAME_BASE=$1
VM_NUM=$2
OSD_PATHS=$3
OSD_SIZE_in_GB=30 # ***** MANUALLLY CONFIGURE *****

OSD_SIZE_in_MB=$((( $OSD_SIZE_in_GB * 1024)))
VM_POINTER=1
OSD_POINTER=1
VM_DISK_POINTER=c

CREATE_OSDs_FILE=/tmp/create_OSDs.sh
> $CREATE_OSDs_FILE
chmod +x $CREATE_OSDs_FILE

function increment_letter {
	pos=$(printf '%d\n' "'$1")
	(( pos += 1 ))
	echo $(printf "\x$(printf %x $pos)")
}

for osd_path in $OSD_PATHS;do
	rm ${osd_path}/${VM_NAME_BASE}*-osd-* || echo "Nothing to remove in " ${osd_path}
	free_space_in_MB=$(df -m $osd_path|tail -n 1|awk '{print $4}')
	osd_num=$((( $free_space_in_MB / $OSD_SIZE_in_MB )))
	i=1
	while [[ $i -le $osd_num ]]
	do
		echo "qemu-img create -f raw ${osd_path}/${VM_NAME_BASE}${VM_POINTER}-osd-${OSD_POINTER} 30G" >> $CREATE_OSDs_FILE
		echo "virsh attach-disk ${VM_NAME_BASE}${VM_POINTER} ${osd_path}/${VM_NAME_BASE}${VM_POINTER}-osd-${OSD_POINTER} vd${VM_DISK_POINTER} --config --cache none" >> $CREATE_OSDs_FILE
		[[ $VM_POINTER -eq $VM_NUM ]] && VM_DISK_POINTER=$(increment_letter $VM_DISK_POINTER)
		VM_POINTER=$((( $VM_POINTER % $VM_NUM + 1 )))
		OSD_POINTER=$((( $OSD_POINTER + 1 )))
		(( i += 1 ))
	done
done

$CREATE_OSDs_FILE
set +ex
