FROM debian:jessie-slim

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update \
&& apt-get -qq install --no-install-recommends curl ca-certificates

ARG FABIO_VERSION=1.5.9
ARG GO_VERSION=1.10.2

RUN curl -LSs https://github.com/fabiolb/fabio/releases/download/v${FABIO_VERSION}/fabio-${FABIO_VERSION}-go${GO_VERSION}-linux_amd64 -o /usr/local/bin/fabio \
&& chmod +x /usr/local/bin/fabio

USER www-data
CMD ["fabio"]

