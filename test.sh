#!/bin/bash

version=3.1.5
#image=quay.io/coreos/etcd:v$version
image=appcelerator/etcd:$version

_cleanup() {
  docker rm -f etcdtest
}

echo "Starting etcd ($image)"
docker run -d -e ETCDCTL_API=3 --name etcdtest $image etcd --listen-client-urls http://0.0.0.0:2379 --advertise-client-urls http://etcdtest:2379 --listen-peer-urls http://0.0.0.0:2380

sleep 1
echo -n "put... "
docker exec etcdtest etcdctl put hello world
if [ $? -ne 0 ]; then
  docker logs etcdtest
  _cleanup
  exit 1
fi

echo -n "get... "
out=$(docker exec etcdtest etcdctl get hello)
echo "$out" | grep -wq world
if [ $? -ne 0 ]; then
  echo
  echo "expected output: world"
  echo "real output: $out"
  _cleanup
  exit 1
fi
echo "OK"
_cleanup
exit 0
