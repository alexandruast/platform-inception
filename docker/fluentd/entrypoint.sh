#!/usr/bin/env bash
touch /var/log/fluentd.pos_file
exec "$@"
