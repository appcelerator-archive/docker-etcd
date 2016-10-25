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
unset TEST
echo "$@" | grep -q -- "--test"
if [[ $? -eq 0 ]]; then
  TEST=1
  ARGS=$(echo $ARGS | sed 's/--test//')
fi


(sleep 3 && ETCDCTL_API=3 /bin/etcdctl put ping pong) &
if [[ -n "$TEST" ]]; then
  /bin/etcd $ARGS &
  echo "Running test..."
  sleep 4
  ETCDCTL_API=3 timeout -t 1 /bin/etcdctl --endpoints http://127.0.0.1:2379 get ping | grep pong && echo "passed" || echo "failed"
else
  exec /bin/etcd $ARGS
fi
