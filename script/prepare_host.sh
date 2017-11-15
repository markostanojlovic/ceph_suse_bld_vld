# checking if there is rsa public key
RSA_PUB_KEY_ROOT=~/.ssh/id_rsa.pub
if [[ -r $RSA_PUB_KEY_ROOT ]]
	then
	echo "RSA key exists."
else
	echo "Missing RSA key."
        #TODO create it if not there
fi

# removing known hosts keys
> ~/.ssh/known_hosts

# host key checking off  
sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config

