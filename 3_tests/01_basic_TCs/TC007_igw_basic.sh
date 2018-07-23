set -x

# get which are the igw nodes 
iSCSI_PORTAL=$(ssh_master "salt -C I@roles:igw grains.item fqdn --out yaml|grep fqdn|sed 's/fqdn: //g'|tr -d ' '")
# run client test script on client node for each igw node 
for portal in $iSCSI_PORTAL
do
	ssh root@${CLIENT_NODE} 'bash -s' < 3_tests/client/igw_client_test.sh $portal
done

echo "Result: OK"

set +x
