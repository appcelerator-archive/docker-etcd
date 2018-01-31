# appcelerator/etcd

etcd3 image based on Alpine Linux

## Usage

    docker run -d -p 2379:2379 -p 2380:2380 appcelerator/etcd

You can set the listen URLs for clients and peers:

    docker run -d -p 2379:2379 -p 2380:2380 appcelerator/etcd --listen-client-urls http://localhost:2379 --advertise-client-urls http://localhost:2379 --listen-peer-urls=http://localhost:2380 --initial-advertise-peer-urls=http://localhost:2380

## Swarm mode

to run an etcd cluster with Docker swarm, you have to specify the name of the service, and optionally the minimum number of seeds for the cluster to be created.

    docker network create --driver overlay db
    docker service create --network db -e SERVICE_NAME=etcd -e MIN_SEEDS_COUNT=3 --replicas 3 --name etcd appcelerator/etcd

or use the sample stack file from this repository:

    docker stack deploy -c ./etcd.yml etcd

## Backup / Restore

In case something goes wrong and the etcd is broken (quorum is lost), there's still a way to fix it if you have a snapshot of the DB.

Prepare the backup file, and make sure the volume mount in etcd-restore.yml is correct.

Remove the existing cluster, we'll start from fresh.

    $ docker stack deploy -c etcd-restore.yml backup

This will create a new cluster with the backuped data. Now we can create the permanent cluster:

    $ docker stack deploy -c etcd.yml etcd

give it time to stabilize, and remove the temporary members:

    $ docker run --rm -ti --network etcd appcelerator/etcd:lastest /bin/bash
    bash-4.4# etcdctl --endpoints etcd:2379 member list
    15e2efb88226a3da, started, etcd-13, http://10.0.2.13:2380, http://10.0.2.13:2379,http://10.0.2.13:4001
    6890ef829475b2cd, started, etcdrestore-6, http://10.0.2.6:2380, http://etcd:2379
    734d10a4021f8332, started, etcdrestore-5, http://10.0.2.5:2380, http://etcd:2379
    b8ecbd5bfd457170, started, etcd-10, http://10.0.2.10:2380, http://10.0.2.10:2379,http://10.0.2.10:4001
    eec3f10e2dfadc0e, started, etcd-14, http://10.0.2.14:2380, http://10.0.2.14:2379,http://10.0.2.14:4001
    fd2519db4a9702be, started, etcdrestore-4, http://10.0.2.4:2380, http://etcd:2379
    bash-4.4# etcdctl --endpoints etcd:2379 member remove 6890ef829475b2cd
    Member 6890ef829475b2cd removed from cluster a12d20375028bb05
    bash-4.4# etcdctl --endpoints etcd:2379 member remove 734d10a4021f8332
    Member 734d10a4021f8332 removed from cluster a12d20375028bb05
    bash-4.4# etcdctl --endpoints etcd:2379 member remove fd2519db4a9702be
    Member fd2519db4a9702be removed from cluster a12d20375028bb05
    bash-4.4# etcdctl --endpoints etcd:2379 member list
    15e2efb88226a3da, started, etcd-13, http://10.0.2.13:2380, http://10.0.2.13:2379,http://10.0.2.13:4001
    b8ecbd5bfd457170, started, etcd-10, http://10.0.2.10:2380, http://10.0.2.10:2379,http://10.0.2.10:4001
    eec3f10e2dfadc0e, started, etcd-14, http://10.0.2.14:2380, http://10.0.2.14:2379,http://10.0.2.14:4001
    bash-4.4# etcdctl --endpoints etcd:2379 endpoint health
    etcd:2379 is healthy: successfully committed proposal: took = 1.869464ms
    exit

    $ docker stack rm backup

## Tags

- 3.0, 3.0.15
- 3.1, 3.1.11
- 3.2, 3.2.15, latest
