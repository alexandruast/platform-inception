FROM fluent/fluentd:v1.2-debian

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update \
&& apt-get -qq install --no-install-recommends curl unzip ca-certificates

RUN gem install \
fluent-plugin-concat \
fluent-plugin-grok-parser \
fluent-plugin-record-modifier \
fluent-plugin-filter_keys \
fluent-plugin-rewrite-tag-filter \
fluent-plugin-loggly \
&& gem sources --clear-all

COPY fluent.conf /fluentd/etc/

RUN useradd --no-create-home --no-log-init --system fluentd \
&& chown -R fluentd:fluentd /fluentd

ENTRYPOINT []

USER fluentd

WORKDIR /fluentd

CMD ["fluentd", "-v", "-c", "/fluentd/etc/fluent.conf"]
