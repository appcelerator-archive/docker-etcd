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
echo "$@" | grep -q -- "-initial-advertise-peer-urls"
if [[ $? -ne 0 ]]; then
  echo "setting initial advertise peer urls and initial cluster"
  cip=$(dig +short $(hostname))
  if [ -z "$cip" ]; then
    # if not resolved by Docker dns, there should be an entry in /etc/hosts
    cip=$(grep $(hostname) /etc/hosts |awk '{print $1}' | head -1)
  fi
  if [ -z "$cip" ]; then
    echo "unable to get this container's IP"
    exit 1
  fi
  ARGS="$ARGS --initial-advertise-peer-urls http://$cip:2380 --initial-cluster default=http://$cip:2380"
fi
ARGS="$@ $ARGS"
unset TEST
echo "$@" | grep -q -- "--test"
if [[ $? -eq 0 ]]; then
  TEST=1
  ARGS=$(echo $ARGS | sed 's/--test//')
fi


(sleep 3 && ETCDCTL_API=3 /bin/etcdctl put ping pong) &
if [[ -n "$TEST" ]]; then
  if [ "${1:0:1}" = '-' ]; then
    echo "Running etcd [/bin/etcd $ARGS]"
    /bin/etcd $ARGS &
  else
    echo "Running etcd [$ARGS]"
    $ARGS &
  fi
  echo "Running test..."
  sleep 4
  ETCDCTL_API=3 timeout -t 1 /bin/etcdctl --endpoints=http://127.0.0.1:2379 get ping | grep pong && echo "passed"
  if [ $? -ne 0 ]; then
    echo "failed"
    exit 1
  fi
else
  if [ "${1:0:1}" = '-' ]; then
    exec /bin/etcd $ARGS
  else
    exec $ARGS
  fi
fi
