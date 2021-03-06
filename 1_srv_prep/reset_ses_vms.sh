#!/bin/bash
# Name: 	reset_ses_vms.sh
# USAGE: 	reset_ses_vms.sh cfg/hostname_arch.config

# Reseting the VMs for the test deployment of Ceph/SES cluster

# Installed pkgs on the host: 
# zypper in -y libvirt virt-install git-core #qemu-uefi-aarch64
# zypper in -y sudo vim wget [SLE15]
# libvirt requirements:
#     - pool name has to be actual directory on the host 

# Clone img VM settings/configs:
# - grub2 settings: /etc/default/grub; grub2-mkconfig -o /boot/grub2/grub.cfg 
#     - console=ttyS0 or ttyAMA0,115200 for arm/aarch64
#     - GRUB_TIMEOUT=1
# - NTP
#     - ntpd started and configured for : cz.pool.ntp.org [SES5]
#     - chronyd started and configured for : cz.pool.ntp.org [SES6]
# - repos are configured and image is patched to latest updates 
# - apparmor disabled
# - IPv6 disabled 
# - Suse Firewall disabled 
# - disabled hostname obtaining from DHCP: /etc/sysconfig/network/dhcp: DHCLIENT_SET_HOSTNAME="no"
# - ssh hey copied in .ssh/authorized_keys 
# - zypper in -y vim wget iputils qemu-guest-agent rsync less nfs-client [for minimal system]
# - installed qemu-guest-agent !!!
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

[[ -z $1 ]] && exit 1 || source $1

set -x

# clean old 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  sudo virsh destroy ${NAME_BASE}${i} || echo "VM not running..."  # Force stop VMs (even if they are not running)
  sudo virsh undefine ${NAME_BASE}${i} --nvram || echo "No VM..."  # Undefine VMs (--nvram option for aarch64)
done

if [[ -n $POOL && -n $NAME_BASE ]]
then
  echo "Deleting old images..."
  sudo rm -rf ${POOL}/${NAME_BASE}* # **** !DANGER! rm -rf / if vars empty! ****
fi

# before cloning, shut off clone VM
sudo virsh destroy $TMPL_VM_NAME || echo "Clone VM shut off: OK"

# clone
for (( i=1; i <= $VM_NUM; i++ ))
do 
  sudo virt-clone --original $TMPL_VM_NAME --name ${NAME_BASE}${i} --file=${POOL}/${NAME_BASE}${i}.qcow2
  # add disks 
  for j in c d e f
  do
    DISK="${POOL}/${NAME_BASE}-osd${i}-${j}"
    sudo qemu-img create -f raw $DISK 30G
    sudo virsh attach-disk ${NAME_BASE}${i} $DISK vd${j} --config 
  done
done 

# start 
for (( i=1; i <= $VM_NUM; i++ ))
do 
  sudo virsh start ${NAME_BASE}${i}
done 

###############################
sleep 30 
counter=1
while sleep 5
do
  if [[ $counter -eq 50 ]];then exit 1;else counter=$((counter+1)); fi 
  sudo virsh domifaddr ${NAME_BASE}${VM_NUM} --source agent --interface eth0|grep ipv4 && break
done
sleep 30
###############################

# get IPs of the VMs
sudo sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config
sudo sed -i "/${NAME_BASE}/d" /etc/hosts
#sudo sed -i "/${NAME_BASE}/d" ~/.ssh/known_hosts
rm -f ~/.ssh/known_hosts
[[ -e /tmp/hostsfile ]] && sudo rm /tmp/hostsfile
touch /tmp/hostsfile

for (( i=1; i <= $VM_NUM; i++ ))
do 
  vmip=$(sudo virsh domifaddr ${NAME_BASE}${i} --source agent --interface eth0|grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  [[ -z $vmip ]] && exit 1
  # checking if not duplicated IP
  grep $vmip /tmp/hostsfile && exit 1 || echo "..."
  # WORKAROUND : since libvirt DHCP is changing ips while VM is running, setting static IPs
  # - limit the range of libvirt DHCP IPs to be up to 150 
  #   EXAMPLE: sudo virsh net-edit default
  #    <dhcp>
  #        <range start='192.168.122.2' end='192.168.122.150'/>
  #    </dhcp>

  if [[ $STATIC_IP -eq 1 ]];then
      ip=${IP_BASE}.${IP_SUFIX}
      sed "s/__IP_ADDR__/${ip}/" $CMD_TMPL > /tmp/static_ip.sh
      ssh root@${vmip} 'bash -s' < /tmp/static_ip.sh
      nohup ssh root@${vmip} 'nohup rcnetwork restart &' &
      sleep 10
      (( IP_SUFIX += 1 ))
      vmip=$ip
      ssh root@${vmip} "ip route add default via 192.168.122.1 dev eth0"
      ssh root@${vmip} "echo nameserver 192.168.122.1|tee -a /etc/resolv.conf"
  fi
  echo $vmip ${NAME_BASE}${i}.${DOMAIN_NAME} ${NAME_BASE}${i} >> /tmp/hostsfile
  # ssh root@${vmip} "hostnamectl set-hostname ${NAME_BASE}${i}.${DOMAIN_NAME}" 
  ssh root@${vmip} "hostnamectl set-hostname --static ${NAME_BASE}${i}.${DOMAIN_NAME}"
  ssh root@${vmip} "hostnamectl set-hostname --transient ${NAME_BASE}${i}.${DOMAIN_NAME}"
  ssh root@${vmip} sed -i '/^DHCLIENT_SET_HOSTNAME/c\DHCLIENT_SET_HOSTNAME=\"no\"' /etc/sysconfig/network/dhcp
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
