#!/bin/bash

version=${1:-latest}
API=3
#image=quay.io/coreos/etcd:v$version
image=appcelerator/etcd:$version

_cleanup() {
  echo "clean up..."
  docker service rm etcdtestcluster >/dev/null 2>&1
  docker rm -f etcdtest etcdtestclt >/dev/null 2<&1
  docker network rm etcdtest >/dev/null 2>&1
  echo "done"
}

docker network create --attachable -d overlay etcdtest >/dev/null
echo "Starting etcd single node ($image)"
#docker run -d -e ETCDCTL_API=$API --name etcdtest $image etcd --listen-client-urls http://0.0.0.0:2379 --advertise-client-urls http://etcdtest:2379 --listen-peer-urls http://0.0.0.0:2380
docker run -d -e ETCDCTL_API=$API --name etcdtest $image etcd --advertise-client-urls http://etcdtest:2379 || exit 1

echo -n "health... "
code=1
SECONDS=0
while [[ $code -ne 0 ]]; do
  cid=$(docker ps --filter=name=etcdtest -q); [[ -z "$cid" ]] && break
  docker exec etcdtest etcdctl --endpoints http://localhost:2379 endpoint health | grep -qw healthy
  code=$?
  [[ $code -eq 0 ]] && echo "healthy" || echo "unhealthy"
  [[ $SECONDS -gt 5 ]] && break
done
if [ $code -ne 0 ]; then
  docker exec etcdtest etcdctl --endpoints http://localhost:2379 endpoint health
  docker logs etcdtest
  echo "FAIL"
  _cleanup
  exit 1
fi

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

echo "single mode test passed"
docker rm -f etcdtest >/dev/null 2>&1

echo "Starting etcd cluster ($image)"
#docker run -d -e ETCDCTL_API=$API --name etcdtest $image etcd --listen-client-urls http://0.0.0.0:2379 --advertise-client-urls http://etcdtest:2379 --listen-peer-urls http://0.0.0.0:2380
docker service create --name etcdtestcluster --replicas 3 --network etcdtest --detach=false -e SERVICE_NAME=etcdtestcluster -e MIN_SEEDS_COUNT=3 $image --advertise-client-urls http://etcdtestcluster:2379

sleep 5

echo -n "vip... "
docker network inspect -v etcdtest | grep "\"etcdtestcluster\":"
if [ $? -ne 0 ]; then
  echo FAIL
  _cleanup
  exit 1
fi

echo "health... "
code=1
SECONDS=0
while [[ $code -ne 0 ]]; do
  docker run --rm --network etcdtest -e ETCDCTL_API=$API $image etcdctl --endpoints "http://etcdtestcluster:2379" endpoint health | grep -qw healthy
  code=$?
  [[ $code -eq 0 ]] && echo "healthy" || echo "unhealthy"
  [[ $SECONDS -gt 5 ]] && break
done
if [ $code -ne 0 ]; then
  docker run --rm --network etcdtest -e ETCDCTL_API=$API $image etcdctl --endpoints "http://etcdtestcluster:2379" --debug=true endpoint health
  docker service ps etcdtestcluster
  docker service logs etcdtestcluster
  echo "FAIL"
  _cleanup
  exit 1
fi

echo -n "put... "
docker run --rm -e ETCDCTL_API=$API --name etcdtestclt --network etcdtest $image etcdctl --endpoints http://etcdtestcluster:2379 put hello world
if [ $? -ne 0 ]; then
  echo "FAIL"
  _cleanup
  exit 1
fi

echo -n "get... "
out=$(docker run --rm -e ETCDCTL_API=$API --name etcdtestclt --network etcdtest $image etcdctl --endpoints http://etcdtestcluster:2379 get hello)
echo "$out" | grep -wq world
if [ $? -ne 0 ]; then
  echo
  echo "expected output: world"
  echo "real output: $out"
  echo "FAIL"
  _cleanup
  exit 1
fi
echo "OK"

echo "cluster mode test passed"

_cleanup
exit 0
