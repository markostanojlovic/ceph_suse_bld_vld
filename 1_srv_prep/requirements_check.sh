#!/bin/bash
# Must be run as root, from the VM host and REPO SSC REG script needs to be copied there also
# Perform system checks and configure them if not as expected

GRUB_CONSOLE=1
GRUB_TIMEOUT=1
FIREWALL_DISABLED=1
APPARMOR_DISABLED=1
IPv6_DISABLED=1
DHCP_HOSTNAME_DISABLED=1
HOSTNAME_SETUP=1; HOSTNAME=qatest.qalab
CLEAN_ZYPP_LOG=1
REPOS_CONFIGURED=1; SCC_REG=sle12sp2_x86.sh
SYS_UPDATED=1
NTP_CONFIG=1; NTP_SERVER=cz.pool.ntp.org

# GRUB CONSOLE
if [[ $GRUB_CONSOLE == 1 ]]
then 
	grep 'console=ttyS0' /etc/default/grub || sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/s/quiet/quiet console=ttyS0/' /etc/default/grub
	if [[ $GRUB_TIMEOUT ]]
	then
		grep 'GRUB_TIMEOUT=1' /etc/default/grub || sed -i '/^GRUB_TIMEOUT/c\GRUB_TIMEOUT=1' /etc/default/grub
	grub2-mkconfig -o /boot/grub2/grub.cfg
fi

# FIREWALL 
if [[ $FIREWALL_DISABLED == 1 ]]
then 
	SuSEfirewall2 status && (SuSEfirewall2 stop; SuSEfirewall2 off)
fi

# APPARMOR
if [[ $APPARMOR_DISABLED == 1 ]]
then 
	systemctl status apparmor.service && (systemctl stop apparmor.service; systemctl disable apparmor.service)
fi

# IPv6
if [[ $IPv6_DISABLED == 1 ]]
then 
	grep net.ipv6 /etc/sysctl.conf || \
	echo "\
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo 1 > /proc/sys/net/ipv6/conf/eth0/disable_ipv6
fi

# DHCP HOSTNAME
if [[ $DHCP_HOSTNAME_DISABLED == 1 ]]
then 
	grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/dhcp && sed -i '/^DHCLIENT_SET_HOSTNAME/c\DHCLIENT_SET_HOSTNAME="no"' /etc/sysconfig/network/dhcp
fi

# HOSTNAME
if [[ $HOSTNAME_SETUP == 1 ]]
then 
	hostnamectl set-hostname $HOSTNAME
fi

# REPOS
if [[ $REPOS_CONFIGURED == 1 ]]
then 
	source /etc/os-release
	zypper rr ${NAME}${VERSION}-${VERSION_ID}-0
	./$SCC_REG
fi

# SYSTEM UPDATE
if [[ $SYS_UPDATED == 1 ]]
then 
	zypper up -y 
fi

# NTP
if [[ $NTP_CONFIG == 1 && $(systemctl status ntpd) ]]
then 
	systemctl enable ntpd
	echo server $NTP_SERVER iburst >> /etc/ntp.conf
	systemctl start ntpd
	systemctl status ntpd
	sntp -S -c $NTP_SERVER
fi

# ZYPPER LOG
if [[ $CLEAN_ZYPP_LOG == 1 ]]
then 
	> /var/log/zypper.log
fi
