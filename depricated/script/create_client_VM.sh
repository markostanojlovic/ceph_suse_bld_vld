#!/bin/bash
# This script is used to be run manually, not as part of automation
# Creating separate client VM for testing ceph client features 
source config/CONFIG
source config/virt_config
# create autoyast file 
autoyast_seed=${BASEDIR}/config/autoyast_${VM_NAME_BASE}.xml
xmlfile=${VM_DIR}/autoyast_client.xml
cp $autoyast_seed $xmlfile
sed -i "s/__ip_default_route__/${VM_HYP_DEF_GW}/" $xmlfile
sed -i "s/__ip_nameserver__/${VM_HYP_DEF_GW}/" $xmlfile
sed -i "s|__ssh_pub_key__|${ssh_pub_key}|" $xmlfile
sed -i "s|__ses_http_link_1__|${ses_url1}|" $xmlfile
sed -i "s/ses5hostnameses5/ses_client/" $xmlfile
sed -i "s/__VMNET_IP_BASE__xxxxx/${VMNET_IP_BASE}.150/" $xmlfile

virt-install \
--name ses_client \
--memory 1024 \
--disk path=${VM_DIR}/ses_client.qcow2,size=20 \
--vcpus 1 \
--network network=${VMNET_NAME},model=virtio \
--noautoconsole \
--location /var/lib/libvirt/images/$ISO_MEDIA \
--initrd-inject=${VM_DIR}/autoyast_client.xml \
--extra-args kernel_args="console=/dev/ttyS0 autoyast=file:/${VM_DIR}/autoyast_client.xml" 

# if no entry in /etc/hosts, create one
[[ cat /etc/hosts|grep ses_client ]] || echo "${VMNET_IP_BASE}.150 ses_client.qatest ses_client" >> /etc/hosts
# add entry in /etc/hosts on master 
ssh root@$MASTER "echo '${VMNET_IP_BASE}.150 ses_client.qatest ses_client' >> /etc/hosts"

