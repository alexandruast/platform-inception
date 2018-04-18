#!/usr/bin/env bash
# this script is a bit against DRY, but using associative arrays would complicate readability
set -eEo pipefail
trap '{ RC=$?; echo "[error] exit code $RC running $(eval echo $BASH_COMMAND)"; exit $RC; }'  ERR

# script directory
HERE="$(cd "$(dirname $0)" && pwd)"
cd "${HERE}"

# if ! git diff-index --quiet HEAD --; then
#   echo "[error] there are uncommited changes in git, commit or stash them!"
#   exit 1
# fi

# retrieving tools
bin_path="${HERE}/mo"
echo "[info] retrieving ${bin_path}"
curl -LSs https://raw.githubusercontent.com/tests-always-included/mo/master/mo -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/jq"
echo "[info] retrieving ${bin_path}"
curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/gosu"
echo "[info] retrieving ${bin_path}"
curl -LSs https://github.com/tianon/gosu/releases/download/1.10/gosu-amd64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/tini"
echo "[info] retrieving ${bin_path}"
curl -LSs https://github.com/krallin/tini/releases/download/v0.17.0/tini-static-amd64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/pumba"
echo "[info] retrieving ${bin_path}"
curl -LSs https://github.com/gaia-adm/pumba/releases/download/0.4.7/pumba_linux_amd64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

if git diff-index --quiet HEAD --; then
  echo "[info] there are no changes to commit"
else
  git commit -m "Updated binary tools"
fi
