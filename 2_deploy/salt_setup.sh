#!/bin/bash
# Name:		salt_setup.sh
# Usage:	./2_deploy/salt_setup.sh ENV_CONF
# Example:	./2_deploy/salt_setup.sh cfg/maiax86_64.cfg 
# Desc:		Installing SALT-STACK and configuring master and minions

if [[ -z $1 ]]
then
  echo "ERROR: ENV_CONF argument missing."
  echo "Example:"
  echo "./2_deploy/salt_setup.sh cfg/maiax86_64.cfg cfg/REPO_ISO_URL_x86_64"
  exit 1
else 
  source $1
fi

set -x

# configure salt master
sudo rm /tmp/configure_salt_master.sh
cat <<EOF > /tmp/configure_salt_master.sh 
set -x
SALT_MASTER_IP=\$(ip a s dev eth0|grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"|grep -v 255)
zypper in -y deepsea
sed -i "/#interface: 0.0.0.0/c\interface: \${SALT_MASTER_IP}" /etc/salt/master
sed -i "/#timeout: 5/c\timeout: 25" /etc/salt/master
sed -i "/#master: salt/c\master: ${NAME_BASE}1" /etc/salt/minion
systemctl enable salt-minion.service;systemctl start salt-minion.service;systemctl status salt-minion.service
systemctl enable salt-master.service;systemctl start salt-master.service;systemctl status salt-master.service
set +x
EOF

ssh root@${NAME_BASE}1 'bash -s' < /tmp/configure_salt_master.sh

# configure salt minions 
sudo rm /tmp/configure_salt_minion.sh
cat <<EOF > /tmp/configure_salt_minion.sh
set -x 
MASTER=${NAME_BASE}1
zypper in -y salt-minion
sed -i "/#master: salt/c\master: \$MASTER" /etc/salt/minion
systemctl enable salt-minion.service;systemctl start salt-minion.service
sed -i "/^server /c\server \$MASTER iburst" /etc/ntp.conf
systemctl stop ntpd
ntpdate -bs cz.pool.ntp.org
systemctl start ntpd
sntp -S -c \$MASTER || echo
set +x
EOF

for (( i=2; i <= $VM_NUM; i++ ))
do
  scp /tmp/configure_salt_minion.sh root@${NAME_BASE}${i}:/tmp/
  ssh root@${NAME_BASE}${i} "chmod +x /tmp/configure_salt_minion.sh"
  ssh root@${NAME_BASE}${i} "nohup /tmp/configure_salt_minion.sh >/tmp/minion.log 2>&1 &"
done 

# waiting for salt-minions to be installed 
sleep 90

# accept salt keys 
ssh root@${NAME_BASE}1 "salt-key --accept-all -y;sleep 5;salt \* test.ping;salt-key --accept-all -y;sleep 2;salt \* test.ping"

set +x

