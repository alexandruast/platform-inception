FROM fluent/fluentd:v1.2-debian

ARG GOSU_VERSION=1.10

RUN apt-get -y -qq update \
&& apt-get -y -qq install --no-install-recommends curl procps inotify-tools \
&& useradd -M -s /bin/false fluentd \
&& chown -R fluentd:fluentd /fluentd

COPY [ \
"gosu-${GOSU_VERSION}.sha256", \
"/tmp/" ]

RUN curl -LSs https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 -o /usr/local/bin/gosu-amd64 \
&& cd /usr/local/bin \
&& grep 'gosu-amd64$' /tmp/gosu-${GOSU_VERSION}.sha256 | tee /tmp/gosu-${GOSU_VERSION}.sha256 \
&& sha256sum -c /tmp/gosu-${GOSU_VERSION}.sha256 \
&& mv gosu-amd64 gosu \
&& chmod +x /usr/local/bin/gosu

RUN gem install fluent-plugin-concat \
&& gem install fluent-plugin-grok-parser \
&& gem install fluent-plugin-record-modifier \
&& gem install fluent-plugin-filter_keys \
&& gem install fluent-plugin-rewrite-tag-filter \
&& gem sources --clear-all

COPY fluent.conf /fluentd/etc/

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["fluentd", "-v", "-c", "/fluentd/etc/fluent.conf"]
