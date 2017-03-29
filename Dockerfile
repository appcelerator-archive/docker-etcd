FROM appcelerator/alpine:3.5.2

RUN apk --update add bind-tools
ENV ETCD_VERSION 3.1.5
RUN curl -L https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz && \
    tar xzf etcd.tar.gz && \
    mv etcd-*/etcd /etcd-*/etcdctl /bin/ && \
    /bin/etcd --version && \
    rm -rf etcd.tar.gz etcd-*

COPY run.sh /bin/

VOLUME /data

EXPOSE 2379 2380 4001 7001

HEALTHCHECK --interval=15s --retries=3 --timeout=15s CMD ETCDCTL_API=3 /bin/etcdctl --endpoints=http://127.0.0.1:2379 get ping | grep -q pong

ENTRYPOINT ["/bin/run.sh"]
