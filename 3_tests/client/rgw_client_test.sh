#!/bin/bash

set -ex 

RGW_HOST=$1
TCP_PORT=$2
curl http://$RGW_HOST:$TCP_PORT

echo 'Result: OK'

set +ex
