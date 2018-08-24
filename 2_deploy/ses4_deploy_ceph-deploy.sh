#!/bin/bash
# TODO most EDIT !!! ****



# deploy SES 
cat <<EOF > /tmp/deploy_SES.sh
function _wait_health_ok {
  timer_checkpoint=\$(date +%s)
  timer=300
  while sleep 5 
  do
    dif=\$((( \$(date +%s)-\$timer_checkpoint )))
    if [[ \$dif -le \$timer ]]
    then 
      if [[ \$(ceph health|head -n 1) -eq "HEALTH_OK" ]]
        then 
        echo "HEALTH_OK"
        break 
      fi
    else
      echo "Error: Ceph HEALTH TIMEOUT!"
      break 
    fi
  done
}

set -x
# installs ceph on each node
ceph-deploy install ses4qa1 ses4qa2 ses4qa3 ses4qa4 ses4qa5
# configures mon nodes
ceph-deploy new ses4qa1 ses4qa2 ses4qa3
# start mon service
ceph-deploy mon create-initial
# configure admin node by creating keyring file 
ceph-deploy admin ses4qa1 ses4qa2 ses4qa3 ses4qa4 ses4qa5
# configure OSDs
ceph-deploy osd prepare \
ses4qa2:vdb ses4qa2:vdc ses4qa2:vdd ses4qa2:vde \
ses4qa3:vdb ses4qa3:vdc ses4qa3:vdd ses4qa3:vde \
ses4qa4:vdb ses4qa4:vdc ses4qa4:vdd ses4qa4:vde \
ses4qa5:vdb ses4qa5:vdc ses4qa5:vdd ses4qa5:vde


# create few pools to avoid "too few PGs per OSD"
sudo ceph osd pool create iscsi 128 128

# wait until cluster is stable
_wait_health_ok

# DEPLOY RGW 
ceph-deploy install --rgw ses4qa2
ceph-deploy --overwrite-conf rgw  create ses4qa2
## verify:
rgw_service_status=\$(ssh ses4qa2 "systemctl status ceph-radosgw@rgw.ses4qa2.service"|grep Active)
echo \$rgw_service_status|grep "active (running)" || echo "Error: RGW service KO."
curl ses4qa2:7480

set +x
EOF

scp /tmp/deploy_SES.sh root@${NAME_BASE}1:/tmp/
ssh root@${NAME_BASE}1 "chmod +x /tmp/deploy_SES.sh"
ssh root@${NAME_BASE}1 "su - cephadm -c 'source /tmp/deploy_SES.sh'"

# DEPLOY OPEN-ATTIC @5th node 
cat <<EOF > /tmp/deploy_openAttic.sh
set -x
sudo zypper in -y openattic
sudo ceph auth add client.openattic mon 'allow *' osd 'allow *'
sudo ceph auth get client.openattic -o /etc/ceph/ceph.client.openattic.keyring
sudo chmod 660 /etc/ceph/ceph.client.openattic.keyring
sudo chown openattic:openattic /etc/ceph/ceph.client.openattic.keyring
sudo oaconfig install
## verify:
systemctl status openattic-systemd.service|grep Active
curl ses4qa5:80
set +x
EOF

scp /tmp/deploy_openAttic.sh root@${NAME_BASE}5:/tmp/
ssh root@${NAME_BASE}5 "chmod +x /tmp/deploy_openAttic.sh"
ssh root@${NAME_BASE}5 "su - cephadm -c 'source /tmp/deploy_openAttic.sh'"

ses4qa3_ip_addr=$(cat /etc/hosts|grep ses4qa3|awk '{print $1}')

# DEPLOY IGW @3rd node 
cat <<EOF > /tmp/lrbd.conf
{
    "auth": [
        {
            "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
            "authentication": "none"
        }
    ],
    "targets": [
        {
            "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
            "hosts": [
                {
                    "host": "ses4qa3.qatest",
                    "portal": "east"
                }
            ]
        }
    ],
    "portals": [
        {
            "name": "east",
            "addresses": [
                "$ses4qa3_ip_addr"
            ]
        }
    ],
    "pools": [
        {
            "pool": "iscsi",
            "gateways": [
                {
                    "target": "iqn.2003-01.org.linux-iscsi.iscsi.x86:demo",
                    "tpg": [
                        {
                            "image": "demo"
                        }
                    ]
                }
            ]
        }
    ]
    }
EOF

cat <<EOF > /tmp/deploy_IGW.sh
set -x
sudo rbd -p iscsi create --size=2G demo
sudo rbd -p iscsi ls 
sudo zypper in -y -t pattern ceph_iscsi 
sudo systemctl enable lrbd
sudo lrbd -f /tmp/lrbd.conf 
sudo systemctl start lrbd 
sudo systemctl status lrbd -l 
sudo targetcli ls 
set +x
EOF

scp /tmp/lrbd.conf root@${NAME_BASE}3:/tmp/
scp /tmp/deploy_IGW.sh root@${NAME_BASE}3:/tmp/
ssh root@${NAME_BASE}3 "chmod +x /tmp/deploy_IGW.sh"
ssh root@${NAME_BASE}3 "su - cephadm -c 'source /tmp/deploy_IGW.sh'"

