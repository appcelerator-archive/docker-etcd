#!/bin/bash

version=${1:-latest}
#image=quay.io/coreos/etcd:v$version
image=appcelerator/etcd:$version

_cleanup() {
  docker service rm etcdtest >/dev/null 2>&1
  docker rm -f etcdtest etcdtestclt >/dev/null 2<&1
  docker network rm etcdtest >/dev/null 2>&1
}

echo "Starting etcd single node ($image)"
#docker run -d -e ETCDCTL_API=3 --name etcdtest $image etcd --listen-client-urls http://0.0.0.0:2379 --advertise-client-urls http://etcdtest:2379 --listen-peer-urls http://0.0.0.0:2380
docker run -d -e ETCDCTL_API=3 --name etcdtest $image etcd --advertise-client-urls http://etcdtest:2379

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

echo "single mode test passed"
docker rm -f etcdtest >/dev/null 2>&1

echo "Starting etcd cluster ($image)"
#docker run -d -e ETCDCTL_API=3 --name etcdtest $image etcd --listen-client-urls http://0.0.0.0:2379 --advertise-client-urls http://etcdtest:2379 --listen-peer-urls http://0.0.0.0:2380
docker network create --attachable -d overlay etcdtest >/dev/null
docker service create --name etcdtest --replicas 3 --network etcdtest --detach=false -e SERVICE_NAME=etcdtest -e MIN_SEEDS_COUNT=3 $image --advertise-client-urls http://etcdtest:2379

sleep 1
echo -n "put... "
docker run --rm -e ETCDCTL_API=3 --name etcdtestclt --network etcdtest $image etcdctl --endpoints http://etcdtest:2379 put hello world
if [ $? -ne 0 ]; then
  echo "failed"
  _cleanup
  exit 1
fi

docker rm -f etcdtestclt >/dev/null 2>/dev/null
echo -n "get... "
out=$(docker run --rm -e ETCDCTL_API=3 --name etcdtestclt --network etcdtest $image etcdctl --endpoints http://etcdtest:2379 get hello)
echo "$out" | grep -wq world
if [ $? -ne 0 ]; then
  echo
  echo "expected output: world"
  echo "real output: $out"
  _cleanup
  exit 1
fi

echo "cluster mode test passed"

_cleanup
exit 0
