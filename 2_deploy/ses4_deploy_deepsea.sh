#!/bin/bash
# openattic is deployed on master node
# to be able to access, configure iptables on thunderx host:
#  - delete all REJECT rules from FORWARD chain
#  - add rule: iptables -t nat -I PREROUTING -d 10.161.32.49 -p tcp --dport 80 -j DNAT --to-destination ses4node1
#  - verify with: iptables -t nat -L PREROUTING

if [[ -z $1 ]]
then
  echo "ERROR: Argument missing. USAGE: .script.sh cfg/CONFIG.cfg"
  exit 1
else 
  source $1
fi

set -ex

# Copy policy.cfg to Master node 
sed "s/__NAMEBASE__/${NAME_BASE}/g" $POLICY_CFG_TEMPLATE > cfg/policy.cfg
scp cfg/policy.cfg root@${NAME_BASE}1:/tmp/

# Deployment script 
DEPL_SCRIPT=/tmp/salt_ses_deploy.sh
cat <<EOF > $DEPL_SCRIPT
salt-run state.orch ceph.stage.0
salt '*' cmd.run 'zypper up -y'
salt-run state.orch ceph.stage.1
cp /tmp/policy.cfg /srv/pillar/ceph/proposals/policy.cfg
salt-run state.orch ceph.stage.2
salt-run state.orch ceph.stage.3
salt-run state.orch ceph.stage.4
EOF

# NFS-ganesha deployment 
NFS_DEPL=/tmp/nfs-ganesha_deployment.sh
cat <<EOF > $NFS_DEPL
zypper in -y nfs-ganesha
zypper in -y nfs-ganesha-ceph
zypper in -y nfs-ganesha-rgw
cat <<EOSF > /etc/ganesha/ganesha.conf
EXPORT
{
  Export_Id = 1;
  Path = "/";
  Pseudo = "/";
  Access_Type = RW;
  Squash = No_Root_Squash;
  FSAL {
    Name = CEPH;
  }
}
EOSF
# RGW FSAL TODO 
sudo systemctl enable rpcbind rpc-statd
sudo systemctl start rpcbind rpc-statd
sudo systemctl enable nfs-ganesha
sudo systemctl start nfs-ganesha
showmount -e
EOF

# Deployment
ssh root@$MASTER 'bash -sx' < $DEPL_SCRIPT
[ $? -eq 0 ] && echo "Deployment OK" || exit 1

ssh root@${NAME_BASE}4 'bash -sx' < $NFS_DEPL

echo "Result: OK"

set +ex
