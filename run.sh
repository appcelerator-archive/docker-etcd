#!/bin/bash

echo -n "$(date +%F\ %T) I | Running "
/bin/etcd --version

ARGS="-data-dir=/data"
echo "$@" | grep -q -- "-listen-peers-urls"
if [[ $? -ne 0 ]]; then
  echo "setting default urls for peers"
  ARGS="$ARGS --listen-peer-urls=http://0.0.0.0:7001,http://0.0.0.0:2380"
fi
echo "$@" | grep -q -- "-listen-client-urls"
if [[ $? -ne 0 ]]; then
  echo "setting default urls for client"
  ARGS="$ARGS --listen-client-urls=http://0.0.0.0:4001,http://0.0.0.0:2379 --advertise-client-urls=http://0.0.0.0:4001,http://0.0.0.0:2379"
fi
ARGS="$ARGS $@"

(sleep 3 && ETCDCTL_API=3 /bin/etcdctl put ping pong) &
exec /bin/etcd $ARGS
