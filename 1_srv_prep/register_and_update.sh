#!/bin/bash

if [[ -z $1 ]]
then
  echo "ERROR: ENV_CONF argument missing. ";exit 1
else
  source $1
fi

for (( i=1; i <= $VM_NUM; i++ ))
do
  ssh root@${NAME_BASE}${i} 'bash -sx' < $SCC_REG_SCRIPT
  ssh root@${NAME_BASE}${i} zypper up -y
done

