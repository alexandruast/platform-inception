FROM alpine:3.7

ARG FABIO_VERSION=1.5.9
ARG GO_VERSION=1.10.2
ARG GOSU_VERSION=1.10

RUN apk add -q --no-cache curl bash inotify-tools \
&& adduser -D -H -s /bin/false fabio fabio

COPY [ \
"gosu-${GOSU_VERSION}.sha256", \
"fabio-${FABIO_VERSION}-go${GO_VERSION}.sha256", \
"/tmp/" ]

RUN curl -LSs https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 -o /usr/local/bin/gosu-amd64 \
&& cd /usr/local/bin \
&& grep 'gosu-amd64$' /tmp/gosu-${GOSU_VERSION}.sha256 | tee /tmp/gosu-${GOSU_VERSION}.sha256 \
&& sha256sum -c /tmp/gosu-${GOSU_VERSION}.sha256 \
&& mv gosu-amd64 gosu \
&& chmod +x /usr/local/bin/gosu

RUN curl -LSs https://github.com/fabiolb/fabio/releases/download/v${FABIO_VERSION}/fabio-${FABIO_VERSION}-go${GO_VERSION}-linux_amd64 -o /usr/local/bin/fabio-${FABIO_VERSION}-go${GO_VERSION}-linux_amd64 \
&& cd /usr/local/bin \
&& grep "fabio-${FABIO_VERSION}-go${GO_VERSION}-linux_amd64$" /tmp/fabio-${FABIO_VERSION}-go${GO_VERSION}.sha256 | tee /tmp/fabio-${FABIO_VERSION}-go${GO_VERSION}.sha256 \
&& sha256sum -c /tmp/fabio-${FABIO_VERSION}-go${GO_VERSION}.sha256 \
&& mv fabio-${FABIO_VERSION}-go${GO_VERSION}-linux_amd64 fabio \
&& chmod +x /usr/local/bin/fabio

COPY fabio.properties /etc/fabio/

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["fabio", "-cfg", "/etc/fabio/fabio.properties"]

