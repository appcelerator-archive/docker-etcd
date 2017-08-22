FROM appcelerator/alpine:3.6.0

RUN apk --no-cache add bind-tools
ENV ETCD_VERSION 3.1.10
RUN curl -L https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz && \
    tar xzf etcd.tar.gz && \
    mv etcd-*/etcd /etcd-*/etcdctl /bin/ && \
    /bin/etcd --version && \
    rm -rf etcd.tar.gz etcd-*

COPY run.sh /bin/
COPY healthcheck.sh /bin/
RUN chmod 755 /bin/healthcheck.sh

VOLUME /data

EXPOSE 2379 2380 4001 7001

ENV MIN_SEEDS_COUNT 2
ENV ETCDCTL_API 3

HEALTHCHECK --start-period=1s --interval=5s --retries=3 --timeout=10s CMD /bin/healthcheck.sh

ENTRYPOINT ["/bin/run.sh"]
