#!/bin/bash

tips=$(dig +short tasks.$SERVICE_NAME)
nbt=$(echo $tips | wc -w)

# we do not have min seeds number yet
# peacefully exit to allow swarm to add new node to DNS list (service.$SERVICE_NAME) 
# see #1462
[[ $nbt -lt ${MIN_SEEDS_COUNT} ]] && exit 0

export ETCDCTL_API=3
/bin/etcdctl --endpoints=http://127.0.0.1:2379 get ping | grep -q pong
