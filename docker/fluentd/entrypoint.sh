#!/usr/bin/env bash
touch /var/log/fluentd.pos_file
CONFIG="/fluentd/etc/fluent.conf"
NEXT_CONFIG="/fluentd/etc/fluent.conf.next"
config_md5_current="$(md5sum ${CONFIG})"
# Get new config file here
{
  while true; do
    if [[ -f ${NEXT_CONFIG} ]]; then
      config_md5_next="$(md5sum ${NEXT_CONFIG})"
      if [[ "${config_md5_current}" != "${config_md5_next}" ]]; then
        if fluentd --dry-run -c ${NEXT_CONFIG}; then
          cp "${NEXT_CONFIG}" "${CONFIG}"
          config_md5_current="${config_md5_next}"
          kill -HUP 1
        fi
      fi
    fi
    sleep 1
  done;
} &
exec "$@"
