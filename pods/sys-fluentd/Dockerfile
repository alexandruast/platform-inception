FROM fluent/fluentd:v1.2-debian

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update \
&& apt-get -qq install --no-install-recommends curl unzip ca-certificates

RUN gem install fluent-plugin-concat \
&& gem install fluent-plugin-grok-parser \
&& gem install fluent-plugin-record-modifier \
&& gem install fluent-plugin-filter_keys \
&& gem install fluent-plugin-rewrite-tag-filter \
&& gem sources --clear-all

COPY fluent.conf /fluentd/etc/

RUN useradd --no-create-home --no-log-init --system fluentd \
&& chown -R fluentd:fluentd /fluentd

ENTRYPOINT []

USER fluentd

WORKDIR /fluentd

CMD ["fluentd", "-v", "-c", "/fluentd/etc/fluent.conf"]
