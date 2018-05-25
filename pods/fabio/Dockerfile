FROM debian:jessie
MAINTAINER Alexandru Ast <alexandru.ast@gmail.com>

RUN apt-get -qq update \
&& apt-get -qq install curl

ARG FABIO_VERSION=1.5.9
ARG GO_VERSION=1.10.2

COPY [ "fabio-${FABIO_VERSION}-go${GO_VERSION}.sha256", "/tmp/" ]

RUN curl -LSs https://github.com/fabiolb/fabio/releases/download/v${FABIO_VERSION}/fabio-${FABIO_VERSION}-go${GO_VERSION}-linux_amd64 -o /usr/local/bin/fabio \
&& chmod +x /usr/local/bin/fabio

COPY fabio.properties /etc/fabio/

USER www-data
CMD ["fabio", "-cfg", "/etc/fabio/fabio.properties"]

