FROM debian:stretch-slim

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -qq \
&& apt-get install -qq --no-install-recommends curl ca-certificates

ARG FABIO_VERSION=1.5.10
ARG GO_VERSION=1.11.1

RUN curl -LSs https://github.com/fabiolb/fabio/releases/download/v${FABIO_VERSION}/fabio-${FABIO_VERSION}-go${GO_VERSION}-linux_amd64 -o /usr/local/bin/fabio \
&& chmod +x /usr/local/bin/fabio

RUN useradd --no-create-home --no-log-init --system fabio

USER fabio

CMD ["exit 1"]

