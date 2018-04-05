FROM appcelerator/alpine:3.7.1

RUN apk --no-cache add bind-tools tini@community
ARG ETCD_VERSION=3.3.3
RUN curl -L https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz && \
    tar xzf etcd.tar.gz && \
    mv etcd-*/etcd /etcd-*/etcdctl /bin/ && \
    /bin/etcd --version && \
    rm -rf etcd.tar.gz etcd-*

COPY run.sh /bin/

VOLUME /data

EXPOSE 2379 2380 4001 7001

ENV MIN_SEEDS_COUNT 3
ENV ETCDCTL_API=3

#HEALTHCHECK --interval=5s --retries=3 --timeout=10s CMD ETCDCTL_API=3 /bin/etcdctl --endpoints=http://127.0.0.1:2379 get ping | grep -q pong

ENTRYPOINT ["/sbin/tini", "--", "/bin/run.sh"]
