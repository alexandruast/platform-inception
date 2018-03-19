FROM fluent/fluentd:v1.1-debian-onbuild

RUN gem install fluent-plugin-concat \
 && gem install fluent-plugin-grok-parser \
 && gem install fluent-plugin-record-modifier \
 && gem install fluent-plugin-filter_keys \
 && gem install fluent-plugin-rewrite-tag-filter \
 && gem sources --clear-all
 