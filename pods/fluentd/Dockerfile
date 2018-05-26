FROM fluent/fluentd:v1.2-debian

RUN gem install fluent-plugin-concat \
&& gem install fluent-plugin-grok-parser \
&& gem install fluent-plugin-record-modifier \
&& gem install fluent-plugin-filter_keys \
&& gem install fluent-plugin-rewrite-tag-filter \
&& gem sources --clear-all

COPY fluent.conf /fluentd/etc/

RUN chown -R nobody:nobody /fluentd

ENTRYPOINT []

USER nobody

CMD ["fluentd", "-v", "-c", "/fluentd/etc/fluent.conf"]
