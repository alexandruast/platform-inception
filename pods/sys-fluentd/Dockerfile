FROM fluent/fluentd:v1.2-debian

ENV DEBIAN_FRONTEND noninteractive

ARG LNAV_VERSION=v0.8.3b

RUN apt-get -qq update \
&& apt-get -qq install --no-install-recommends curl unzip ca-certificates

RUN curl -LSs https://github.com/tstack/lnav/releases/download/${LNAV_VERSION}/lnav-${LNAV_VERSION}-linux-64bit.zip -o /tmp/lnav-linux-64bit.zip \
&& unzip /tmp/lnav-linux-64bit.zip -d /usr/local/bin \
&& rm -f /tmp/lnav-linux-64bit.zip

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
