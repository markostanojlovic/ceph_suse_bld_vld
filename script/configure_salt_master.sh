set -ex
SALT_MASTER_HOSTNAME=$1
SALT_MASTER_IP=$2

zypper in -y deepsea
sed -i "/#interface: 0.0.0.0/c\interface: ${SALT_MASTER_IP}" /etc/salt/master
sed -i "/#timeout: 5/c\timeout: 25" /etc/salt/master
sed -i "/#master: salt/c\master: ${SALT_MASTER_HOSTNAME}" /etc/salt/minion
systemctl enable salt-minion.service;systemctl start salt-minion.service
systemctl enable salt-master.service;systemctl start salt-master.service
echo "export PS1='\e[1;91m[ceph:\w ]$ \e[m'" >> ~/.profile

systemctl stop ntpd
ntpdate -bs cz.pool.ntp.org
sed -i "/server $SALT_MASTER_HOSTNAME iburst/c\server cz.pool.ntp.org iburst" /etc/ntp.conf
systemctl start ntpd
sntp -S -c $SALT_MASTER_HOSTNAME || echo

salt-key --accept-all -y
sleep 1
salt \* test.ping || echo
sleep 1
salt-key --accept-all -y
sleep 1
salt \* test.ping || echo
