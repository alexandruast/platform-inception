FROM debian:stretch-slim

ENV TINI_VERSION=v0.18.0
ENV GOSU_VERSION=1.10
ENV LNAV_VERSION=v0.8.3b

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update >/dev/null \
&& apt-get install -y --no-install-recommends curl unzip ca-certificates >/dev/null \
&& curl -LSs https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-arm64 -o /usr/local/bin/gosu \
&& chmod +x /usr/local/bin/gosu \
&& curl -LSs https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 -o /usr/local/bin/tini \
&& chmod +x /usr/local/bin/tini \
&& tini gosu nobody true

RUN curl -LSs https://github.com/tstack/lnav/releases/download/${LNAV_VERSION}/lnav-${LNAV_VERSION}-linux-64bit.zip -o /fluentd/lnav-linux-64bit.zip \
&& unzip /fluentd/lnav-linux-64bit.zip -d /usr/local/bin
 
RUN apt-get update >/dev/null \
&& apt-get install -y --no-install-recommends ruby >/dev/null \
&& echo 'gem: --no-document' >> /etc/gemrc \
&& gem install oj -v 3.3.10 \
&& gem install json -v 2.1.0 \
&& gem install fluentd -v 1.1.3 \
&& gem install fluent-plugin-concat \
&& gem install fluent-plugin-grok-parser \
&& gem install fluent-plugin-record-modifier \
&& gem install fluent-plugin-filter_keys \
&& gem install fluent-plugin-rewrite-tag-filter \
&& gem sources --clear-all \
&& rm -fr /usr/lib/ruby/gems/*/cache/*.gem
 
RUN BUILD_DEPS="make gcc g++ libc-dev ruby-dev bzip2 gnupg dirmngr" \
&& update-ca-certificates \
&& curl -LSf https://github.com/jemalloc/jemalloc/releases/download/4.5.0/jemalloc-4.5.0.tar.bz2 -o /tmp/jemalloc-4.5.0.tar.bz2 \
&& cd /tmp && tar -xjf jemalloc-4.5.0.tar.bz2 && cd jemalloc-4.5.0 \
&& ./configure && make \
&& mv lib/libjemalloc.so.2 /usr/lib \
&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${BUILD_DEPS} \
&& rm -rf /var/lib/apt/lists/* \
&& rm -rf /tmp/* /var/tmp/*

RUN mkdir -p /fluentd/log \
&& mkdir -p /fluentd/etc /fluentd/plugins

COPY fluent.conf /fluentd/etc/

ENV LD_PRELOAD="/usr/lib/libjemalloc.so.2"

RUN useradd --no-create-home --no-log-init --system fluentd \
&& chown -R fluentd:fluentd /fluentd

WORKDIR /fluentd

CMD ["tini", "gosu", "fluentd", "fluentd -v -c /fluentd/etc/fluent.conf"]
