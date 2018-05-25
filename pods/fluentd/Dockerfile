FROM fluent/fluentd:v1.2-debian
MAINTAINER Alexandru Ast <alexandru.ast@gmail.com>

RUN apt-get -y -qq update \
&& apt-get -y -qq install --no-install-recommends curl \
&& useradd -M -s /bin/false fluentd \
&& chown -R fluentd:fluentd /fluentd

RUN gem install fluent-plugin-concat \
&& gem install fluent-plugin-grok-parser \
&& gem install fluent-plugin-record-modifier \
&& gem install fluent-plugin-filter_keys \
&& gem install fluent-plugin-rewrite-tag-filter \
&& gem sources --clear-all

COPY fluent.conf /fluentd/etc/

USER www-data

CMD ["fluentd", "-v", "-c", "/fluentd/etc/fluent.conf"]
