source ${BASEDIR}/config/virt_config
echo "Preparing the environment..."
echo "Checking if VMs are existing..."
virsh list --all|grep ${VM_NAME_BASE} && NO_VMs=0 || NO_VMs=1
if [[ $NO_VMs -eq 0 ]]
then
for (( NODE_NUMBER=1; NODE_NUMBER <=$VM_NUM; NODE_NUMBER++ ))
do
	virsh destroy ${VM_NAME_BASE}${NODE_NUMBER} || echo "VM not running..." 	# Force stop VMs (even if they are not running)
	virsh undefine ${VM_NAME_BASE}${NODE_NUMBER} --nvram || echo "No VM..."		# Undefine VMs (--nvram option for aarch64)
done
fi
# Delete disk images
rm ${VM_DIR}/${VM_NAME_BASE}*
# Generate autoyast xml files:
> /tmp/hosts_file
for (( NODE_NUMBER=1; NODE_NUMBER <=$VM_NUM; NODE_NUMBER++ ))
do
xmlfile=${VM_DIR}/autoyast_${VM_NAME_BASE}${NODE_NUMBER}.xml
cp $autoyast_seed $xmlfile
sed -i "s/__ip_default_route__/${VM_HYP_DEF_GW}/" $xmlfile
sed -i "s/__ip_nameserver__/${VM_HYP_DEF_GW}/" $xmlfile
sed -i "s|__ssh_pub_key__|${ssh_pub_key}|" $xmlfile
sed -i "s/ses5hostnameses5/${VM_NAME_BASE}${NODE_NUMBER}/" $xmlfile
sed -i "s/__VMNET_IP_BASE__xxxxx/${VMNET_IP_BASE}.${VM_IP}/" $xmlfile
sed -i "s|__ses_http_link_1__|${ses_url1}|" $xmlfile
echo ${VMNET_IP_BASE}.${VM_IP} ${VM_NAME_BASE}${NODE_NUMBER}.${DOMAIN} ${VM_NAME_BASE}${NODE_NUMBER} >> /tmp/hosts_file
(( VM_IP+=1 ))
done

# Add hostnames and IP addresses in the hosts file of the VM host
cat /etc/hosts|grep $VMNET_IP_BASE.${VM_NUM} || cat /tmp/hosts_file >> /etc/hosts

CREATE_VM_SCRIPT=${VM_DIR}/create_VMs.sh
> $CREATE_VM_SCRIPT

# check if the installation ISO is available
[[ -r /var/lib/libvirt/images/$ISO_MEDIA ]] || (echo "ERROR: No installation ISO: /var/lib/libvirt/images/${ISO_MEDIA}";exit 1)

for (( NODE_NUMBER=1; NODE_NUMBER <=$VM_NUM; NODE_NUMBER++ ))
do
echo "virt-install \
--name ${VM_NAME_BASE}$NODE_NUMBER \
--memory 1024 \
--disk path=${VM_DIR}/${VM_NAME_BASE}$NODE_NUMBER.qcow2,size=20 \
--vcpus 1 \
--network network=${VMNET_NAME},model=virtio \
--noautoconsole \
--location /var/lib/libvirt/images/$ISO_MEDIA \
--initrd-inject=${VM_DIR}/autoyast_${VM_NAME_BASE}${NODE_NUMBER}.xml \
--extra-args kernel_args=\"console=/dev/ttyS0 autoyast=file:/${VM_DIR}/autoyast_${VM_NAME_BASE}${NODE_NUMBER}.xml\" " >> $CREATE_VM_SCRIPT
done
chmod +x $CREATE_VM_SCRIPT
source $CREATE_VM_SCRIPT


