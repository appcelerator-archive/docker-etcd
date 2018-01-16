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

## Tags

- 3.0, 3.0.15
- 3.1, 3.1.11
- 3.2, 3.2.14, latest
