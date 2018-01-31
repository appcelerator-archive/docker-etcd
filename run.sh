#!/bin/bash
if [[ "${1:0:1}" != '-' && "x$1" != "x/bin/etcd" ]]; then
  exec $@
fi

echo -n "$(date +%F\ %T) I | Running "
/bin/etcd --version

INITIAL_CLUSTER_TOKEN=etcd-cluster
INITIAL_CLUSTER_STATE=new
NODE_NAME=default
# lock file to make sure we're not running multiple containers on the same volume
LOCK_FILE=/data/ctr.lck

ARGS="--data-dir=/data"
echo "$@" | grep -q -- "-auto-compaction-retention"
if [[ $? -ne 0 ]]; then
  echo "setting default auto compaction retention"
  ARGS="$ARGS --auto-compaction-retention=1"
fi
echo "$@" | grep -q -- "-listen-peers-urls"
if [[ $? -ne 0 ]]; then
  echo "setting default urls for peers"
  ARGS="$ARGS --listen-peer-urls=http://0.0.0.0:7001,http://0.0.0.0:2380"
fi
echo "$@" | grep -q -- "-listen-client-urls"
if [[ $? -ne 0 ]]; then
  echo "setting default urls for client"
  ARGS="$ARGS --listen-client-urls=http://0.0.0.0:4001,http://0.0.0.0:2379"
fi
echo "$@" | grep -q -- "-initial-advertise-peer-urls"
if [[ $? -ne 0 ]]; then
  echo "setting initial advertise peer urls and initial cluster"
  SECONDS=0
  echo "resolving the container IP with Docker DNS..."
  while [ -z "$cip" ]; do 
    cip=$(dig +short $(hostname))
    # checking that the returned IP is really an IP
    echo "$cip" | egrep -qe "^[0-9\.]+$"
    if [ -z "$cip" ]; then
      sleep 1
    fi
    [[ $SECONDS -gt 10 ]] && break
  done
  echo "$cip" | egrep -qe "^[0-9\.]+$"
  if [ $? -ne 0 ]; then
    # if not resolved by Docker dns, there should be an entry in /etc/hosts
    echo "warning: unable to resolve this container's IP ($cip), switching back to /etc/hosts"
    cip=$(grep $(hostname) /etc/hosts |awk '{print $1}' | head -1)
    echo "found IP in /etc/hosts: $cip"
  else
    echo "resolved IP: $cip"
  fi
  echo "$cip" | egrep -qe "^[0-9\.]+$"
  if [ $? -ne 0 ]; then
    echo "error: unable to get this container's IP ($cip)"
    exit 1
  fi
  if [[ -n "$SERVICE_NAME" ]]; then
    INITIAL_CLUSTER_TOKEN=$SERVICE_NAME

    echo "building a seeds list for cluster $SERVICE_NAME"
    # IP of the service tasks
    typeset -i nbt
    nbt=0
    SECONDS=0
    echo "waiting for the min seeds count ($MIN_SEEDS_COUNT)"
    while [[ $nbt -lt ${MIN_SEEDS_COUNT} ]]; do
      tips=$(dig +short tasks.$SERVICE_NAME)
      nbt=$(echo $tips | wc -w)
      [[ $SECONDS -gt 30 ]] && break
    done
    if [[ $nbt -lt ${MIN_SEEDS_COUNT} ]]; then
      echo "error: couldn't reach the min seeds count after $SECONDS sec, only $nbt tasks were found"
      exit 1
    else
      echo "$nbt seeds found"
    fi
    for tip in $tips; do
      name="${SERVICE_NAME}-${tip##*.}"
      [[ -z "$INITIAL_CLUSTER" ]] && INITIAL_CLUSTER="$name=http://$tip:2380" || INITIAL_CLUSTER="$INITIAL_CLUSTER,$name=http://$tip:2380"
      if [[ "$cip" = "$tip" ]]; then
        NODE_NAME=$name
      else
        # check if a cluster already exists
	echo "checking existing cluster with $name"
        timeout -t 2 etcdctl --endpoints $tip:2379 get probe-members >/dev/null 2>&1 && INITIAL_CLUSTER_STATE=existing
      fi
    done
  else
      INITIAL_CLUSTER="default=http://$cip:2380"
  fi
  if [[ "$INITIAL_CLUSTER_STATE" = "existing" ]]; then
    # first, remove dead members
    peers=$(etcdctl --endpoints $SERVICE_NAME:2379 member list | cut -d, -f1,2,3,4 | tr -d ' ')
    for p in $peers; do
      peerURL=$(echo $p | cut -d, -f4)
      [[ $peerURL = "http://$cip:2380" ]] && continue
      peerID=$(echo $p | cut -d, -f1)
      peerStatus=$(echo $p | cut -d, -f2)
      peerName=$(echo $p | cut -d, -f3)
      echo "checking peer $p"
      curl -sf $peerURL/version >/dev/null
      if [[ $? -ne 0 ]]; then
        if [[ "x$peerStatus" = "xstarted" ]]; then
          echo "peer check failed, attempting to remove ${peerName:-unknown} ($peerID)"
	  etcdctl --endpoints $SERVICE_NAME:2379 member remove $peerID
        fi
        echo "peer check failed or peer not started, removing $peerID / $peerURL from initial cluster"
	echo $INITIAL_CLUSTER | grep -q $peerURL &&
	    INITIAL_CLUSTER=$(echo $INITIAL_CLUSTER | sed "s%[^,]*=${peerURL}%%" | sed "s/,$//" | sed "s/^,//" | sed "s/,,/,/")
      else
        echo "peer check successful for $peerName"
      fi
    done
    # then, add the new node
    echo "prepare this node as a new cluster member"
    etcdctl --endpoints $SERVICE_NAME:2379 member add $NODE_NAME --peer-urls=http://$cip:2380
  fi
  # to restore a db, create a temporary service with
  #   restart condition = none
  #   env var RESTORED_SERVICE = name of the permanent service (should be down)
  #   mount the backup file on /backup.db
  #   add the RESTORED_SERVICE name as alias on the network
  if [[ -n "$RESTORED_SERVICE" ]]; then
    if [[ ! -f /backup.db ]]; then
      echo "/backup.db not found, abort"
      exit 1
    fi
    INITIAL_CLUSTER_TOKEN=$RESTORED_SERVICE
    echo "restoring snapshot..."
    ETCDCTL_API=3 etcdctl snapshot restore /backup.db \
      --name $NODE_NAME \
      --initial-cluster $INITIAL_CLUSTER \
      --initial-cluster-token $INITIAL_CLUSTER_TOKEN \
      --initial-advertise-peer-urls http://$cip:2380 || exit 1
    echo "done"
    echo "starting etcd..."
    etcd \
      --name $NODE_NAME \
      --listen-client-urls http://$cip:2379 \
      --advertise-client-urls http://$RESTORED_SERVICE:2379 \
      --listen-peer-urls http://$cip:2380
    exit $?
  fi
  echo "initial cluster is $INITIAL_CLUSTER ($INITIAL_CLUSTER_STATE)"
  ARGS="$ARGS --name $NODE_NAME --initial-advertise-peer-urls http://$cip:2380 --initial-cluster $INITIAL_CLUSTER --initial-cluster-token $INITIAL_CLUSTER_TOKEN --initial-cluster-state $INITIAL_CLUSTER_STATE"
fi
echo "$@" | grep -q -- "-advertise-client-urls"
if [[ $? -ne 0 ]]; then
  echo "setting default advertise urls for client"
  [[ -z "$cip" ]] && cip=$(dig +short $(hostname))
  [[ -z "$cip" ]] && exit 1
  ARGS="$ARGS --advertise-client-urls=http://${cip}:4001,http://${cip}:2379"
fi

[ $# -ne 0 ] && ARGS="$@ $ARGS"
unset TEST
echo "$@" | grep -q -- "--test"
if [[ $? -eq 0 ]]; then
  TEST=1
  ARGS=$(echo $ARGS | sed 's/--test *//')
fi


(sleep 3 && ETCDCTL_API=3 /bin/etcdctl put ping pong) &
if [[ -n "$TEST" ]]; then
  if [ "${ARGS:0:1}" = '-' ]; then
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
  if [ "${ARGS:0:1}" = '-' ]; then
    exec flock -xn $LOCK_FILE /bin/etcd $ARGS
  else
    exec $ARGS
  fi
fi
