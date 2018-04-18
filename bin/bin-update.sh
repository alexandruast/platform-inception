#!/usr/bin/env bash
set -eEo pipefail
trap '{ RC=$?; echo "[error] exit code $RC running $(eval echo $BASH_COMMAND)"; exit $RC; }'  ERR

# script directory
HERE="$(cd "$(dirname $0)" && pwd)"
cd "${HERE}"

if ! git diff-index --quiet HEAD --; then
  echo "[error] there are uncommited changes in git, commit or stash them!"
  exit 1
fi

# retrieving tools
curl -LSs https://raw.githubusercontent.com/tests-always-included/mo/master/mo -o "${HERE}/mo" && chmod +x "${HERE}/mo"
curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o "${HERE}/jq" && chmod +x "${HERE}/jq"
curl -LSs https://github.com/tianon/gosu/releases/download/1.10/gosu-amd64 -o "${HERE}/gosu" && chmod +x "${HERE}/gosu"
curl -LSs https://github.com/krallin/tini/releases/download/v0.17.0/tini-static-amd64 -o "${HERE}/tini" && chmod +x "${HERE}/tini"
curl -LSs https://github.com/gaia-adm/pumba/releases/download/0.4.7/pumba_linux_amd64 -o "${HERE}/pumba" && chmod +x "${HERE}/pumba"

