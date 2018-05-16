#!/usr/bin/env bash
set -euEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

touch /var/log/fluentd.pos_file
CONFIG="/fluentd/etc/fluent.conf"
config_md5_current="$(md5sum ${CONFIG})"

{
  while true; do
    inotifywait -e modify,move,create,delete ${CONFIG}
    config_md5_next="$(md5sum ${CONFIG})"
    if [[ "${config_md5_current}" != "${config_md5_next}" ]]; then
      if fluentd --dry-run -c ${CONFIG}; then
        config_md5_current="${config_md5_next}"
        kill -HUP 1
      fi
    fi
  done;
} &

exec gosu fluentd "$@"
