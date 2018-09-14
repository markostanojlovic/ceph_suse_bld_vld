#!/bin/bash
# Name: 	reset_ses_vms.sh
# USAGE: 	reset_ses_vms.sh cfg/hostname_arch.config

# Reseting the VMs for the test deployment of Ceph/SES cluster

# Installed pkgs on the host: 
# zypper in -y libvirt virt-install git-core #qemu-uefi-aarch64

# Clone img VM settings/configs:
# - grub2 settings: /etc/default/grub; grub2-mkconfig -o /boot/grub2/grub.cfg 
#     - console=ttyS0 or ttyAMA0,115200 for SLES12SP3
#     - GRUB_TIMEOUT=2
# - ntpd started and configured for : cz.pool.ntp.org
# - repos are configured and image is patched to latest updates 
# - apparmor disabled
# - IPv6 disabled 
# - Suse Firewall disabled 
# - disabled hostname obtaining from DHCP: /etc/sysconfig/network/dhcp: DHCLIENT_SET_HOSTNAME="no"
# - ssh hey copied in .ssh/authorized_keys 
# - cleaned /var/log/zypper.log logs 

# Most important vars to setup:
# - number of VMs
# - VM template image
# - libvirt pool for storing images 

# User must have passwordless sudo privileges 

#=============================================
# SLES12SP3 image for cloud/terraform 
#=============================================
# virt-install \
# --name sles12sp3_tf_img \
# --memory 1024 \
# --disk path=/VM/sles12sp3_tf_img.qcow2,size=30 \
# --vcpus 1 \
# --network network=vnet1,model=virtio \
# --os-type linux \
# --noautoconsole \
# --os-variant sles12sp3 \
# --graphics vnc \
# --location /var/lib/libvirt/images/SLE-12-SP3-Server-DVD-x86_64-GM-DVD1.iso \
# --initrd-inject=/VM/autoyast_SLES12SP3_for_cloud_image.xml \
# --extra-args kernel_args="console=/dev/ttyS0 autoyast=file://VM/autoyast_SLES12SP3_for_cloud_image.xml"
#=============================================

if [[ -z $1 ]]
then
  echo "ERROR: ENV_CONF argument missing."; exit 1
else
  source $1
fi

set -x

# get IPs of the VMs
sudo sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config
sudo sed -i "/${NAME_BASE}/d" /etc/hosts
#sudo sed -i "/${NAME_BASE}/d" ~/.ssh/known_hosts
rm -f ~/.ssh/known_hosts
[[ -e /tmp/hostsfile ]] && sudo rm /tmp/hostsfile
touch /tmp/hostsfile

for (( i=1; i <= $VM_NUM; i++ ))
do 
  vmip=$(sudo virsh domifaddr ${NAME_BASE}${i}|grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  [[ -z $vmip ]] && exit 1
  ssh root@${vmip} "hostnamectl set-hostname --static ${NAME_BASE}${i}.${DOMAIN_NAME}" 
  echo $vmip ${NAME_BASE}${i}.${DOMAIN_NAME} ${NAME_BASE}${i} >> /tmp/hostsfile
  echo alias ${NAME_BASE}${i}="'ssh root@${NAME_BASE}${i}'" >> ~/.bashrc
done
cat /tmp/hostsfile
sudo bash -c 'cat /tmp/hostsfile >> /etc/hosts'
# removing duplicate lines 
awk '!seen[$0]++' /etc/hosts > /tmp/hosts
awk '!seen[$0]++' ~/.bashrc > /tmp/bashrc
sudo cp /tmp/hosts /etc/hosts
sudo cp /tmp/bashrc ~/.bashrc

# copy hosts file 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  scp /tmp/hostsfile root@${NAME_BASE}${i}:/tmp/
  ssh root@${NAME_BASE}${i} "cat /tmp/hostsfile >> /etc/hosts"
done

echo "Result: OK"
set +x
