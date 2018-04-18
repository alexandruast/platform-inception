#!/usr/bin/env bash
# this script is a bit against DRY, but using associative arrays would complicate readability
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
echo "[info] downloading tools..."

bin_path="${HERE}/mo"
curl -# -LSs https://raw.githubusercontent.com/tests-always-included/mo/master/mo -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/jq"
curl -#LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/gosu"
curl -#LSs https://github.com/tianon/gosu/releases/download/1.10/gosu-amd64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/tini"
curl -#LSs https://github.com/krallin/tini/releases/download/v0.17.0/tini-static-amd64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

bin_path="${HERE}/pumba"
curl -#LSs https://github.com/gaia-adm/pumba/releases/download/0.4.7/pumba_linux_amd64 -o "${bin_path}"
chmod +x "${bin_path}"
git update-index --chmod=+x "${bin_path}"
git add "${bin_path}"

if git diff-index --quiet HEAD --; then
  echo "[info] commit changes..."
  git commit -m "Updated binary tools"
else
  echo "[info] there are no changes to commit"
fi

