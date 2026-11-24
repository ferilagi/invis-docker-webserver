#!/usr/bin/env bash
# Cari tag base image terbaru di Docker Hub untuk php & node yang kita pakai.
# Butuh: curl, jq.
#
# Output (siap di-eval):
#   PHP_LATEST, PHP_LATEST_SAME_ALPINE, NODE_LATEST, NODE_LATEST_SAME_ALPINE
# `*_SAME_ALPINE` = rilis terbaru yang masih di alpine versi sekarang (patch-only update).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
eval "$(bash scripts/security/current-versions.sh)"

php_mm="${PHP_VERSION%.*}"       # 8.4
node_major="${NODE_VERSION%%.*}" # 26

fetch_names() { # $1=repo $2=filter nama
  local repo="$1" filter="$2" page
  for page in 1 2; do
    curl -fsSL --retry 3 --max-time 30 \
      "https://hub.docker.com/v2/repositories/library/${repo}/tags?page_size=100&page=${page}&name=${filter}&ordering=last_updated" \
      | jq -r '.results[]?.name'
  done
}

pick() { # stdin: nama tag, $1: regex -> tag terbaru
  grep -E "$1" | sort -V | tail -1 || true
}

php_re="^${php_mm//./\\.}\.[0-9]+-fpm-alpine"
node_re="^${node_major}\.[0-9]+\.[0-9]+-alpine"

PHP_LATEST="$(fetch_names php "${php_mm}." | pick "${php_re}[0-9]+\.[0-9]+$")"
PHP_LATEST_SAME_ALPINE="$(fetch_names php "${php_mm}." | pick "${php_re}${PHP_ALPINE//./\\.}$")"
NODE_LATEST="$(fetch_names node "${node_major}." | pick "${node_re}[0-9]+\.[0-9]+$")"
NODE_LATEST_SAME_ALPINE="$(fetch_names node "${node_major}." | pick "${node_re}${NODE_ALPINE//./\\.}$")"

for var in PHP_LATEST NODE_LATEST; do
  if [ -z "${!var}" ]; then
    echo "gagal mengambil tag terbaru dari Docker Hub ($var)" >&2
    exit 1
  fi
done

cat <<EOF
PHP_LATEST=$PHP_LATEST
PHP_LATEST_SAME_ALPINE=${PHP_LATEST_SAME_ALPINE:-$PHP_LATEST}
NODE_LATEST=$NODE_LATEST
NODE_LATEST_SAME_ALPINE=${NODE_LATEST_SAME_ALPINE:-$NODE_LATEST}
EOF
