FROM fluent/fluentd:v1.1-debian

RUN apt-get -y -qq update \
&& apt-get -y -qq install --no-install-recommends procps \
&& gem install fluent-plugin-concat \
&& gem install fluent-plugin-grok-parser \
&& gem install fluent-plugin-record-modifier \
&& gem install fluent-plugin-filter_keys \
&& gem install fluent-plugin-rewrite-tag-filter \
&& gem sources --clear-all

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["fluentd", "-v", "-c", "/fluentd/etc/fluent.conf"]