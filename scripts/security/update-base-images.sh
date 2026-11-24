#!/usr/bin/env bash
# Bandingkan base image di repo dengan rilis terbaru di Docker Hub, lalu tulis
# versi baru ke Dockerfile, Dockerfile.withoutNodejs, dan build script.
# Tidak melakukan commit/push/PR: itu tugas workflow (security-auto-update.yml).
#
# Env:
#   ALPINE_MODE=same|latest  same (default) = tetap di alpine 3.x sekarang, hanya patch PHP/Node
#   DRY_RUN=1                hanya tampilkan, jangan ubah file
#
# Butuh: curl, jq. Output untuk GitHub Actions: changed, php_version, node_version, ...
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

ALPINE_MODE="${ALPINE_MODE:-same}"
DRY_RUN="${DRY_RUN:-0}"

eval "$(bash scripts/security/current-versions.sh)"
eval "$(bash scripts/security/latest-upstream.sh)"

if [ "$ALPINE_MODE" = "latest" ]; then
  php_target="$PHP_LATEST"
  node_target="$NODE_LATEST"
else
  php_target="$PHP_LATEST_SAME_ALPINE"
  node_target="$NODE_LATEST_SAME_ALPINE"
fi

new_php="${php_target%-fpm-alpine*}"      # 8.4.28
new_php_alpine="${php_target##*-alpine}"  # 3.23
new_node="${node_target%-alpine*}"        # 26.13.1
new_node_alpine="${node_target##*-alpine}"

changed=false
[ "$new_php" != "$PHP_VERSION" ] && changed=true
[ "$new_php_alpine" != "$PHP_ALPINE" ] && changed=true
[ "$new_node" != "$NODE_VERSION" ] && changed=true
[ "$new_node_alpine" != "$NODE_ALPINE" ] && changed=true

echo "sekarang : php ${PHP_VERSION} (alpine ${PHP_ALPINE}), node ${NODE_VERSION} (alpine ${NODE_ALPINE})"
echo "upstream : php ${new_php} (alpine ${new_php_alpine}), node ${new_node} (alpine ${new_node_alpine})"
echo "berubah  : ${changed} (mode alpine: ${ALPINE_MODE})"

set_output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s\n' "$1" >>"${GITHUB_OUTPUT}"
  fi
}

set_output "changed=${changed}"
set_output "php_version=${new_php}"
set_output "php_alpine=${new_php_alpine}"
set_output "node_version=${new_node}"
set_output "node_alpine=${new_node_alpine}"
set_output "php_from=${PHP_VERSION}"
set_output "node_from=${NODE_VERSION}"

if [ "$changed" = "false" ]; then
  echo "base image sudah versi terbaru, tidak ada yang diubah"
  exit 0
fi

# Ganti bagian teks yang match regex pada 1 baris, sisa baris (termasuk CRLF /
# akhir file tanpa newline) dibiarkan apa adanya. Tidak pakai sed -i karena
# sed di Windows (Git Bash) mengubah CRLF file jadi LF.
replace_in_file() { # $1=file $2=regex ERE $3=teks pengganti
  local file="$1" re="$2" repl="$3" line match prefix suffix
  [ -f "$file" ] || {
    echo "!! file tidak ditemukan: $file" >&2
    return 1
  }
  local tmpfile
  tmpfile="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ $re ]]; then
      match="${BASH_REMATCH[0]}"
      prefix="${line%%"$match"*}"
      suffix="${line#*"$match"}"
      line="${prefix}${repl}${suffix}"
    fi
    printf '%s\n' "$line" >>"$tmpfile"
  done <"$file"

  if [ -z "$(tail -c 1 "$file")" ]; then
    # file asli berakhir dengan newline
    mv "$tmpfile" "$file"
  else
    # file asli tanpa newline di akhir: jangan tambahkan
    printf '%s' "$(cat "$tmpfile")" >"$file"
    rm -f "$tmpfile"
  fi
}

apply() { # $1=file $2=regex $3=teks pengganti
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] $1: /$2/ -> $3"
  else
    replace_in_file "$1" "$2" "$3"
  fi
}

apply Dockerfile.withoutNodejs \
  '^FROM php:[0-9]+\.[0-9]+\.[0-9]+-fpm-alpine[0-9]+\.[0-9]+' \
  "FROM php:${new_php}-fpm-alpine${new_php_alpine}"

apply Dockerfile \
  '^FROM node:[0-9]+\.[0-9]+\.[0-9]+-alpine[0-9]+\.[0-9]+' \
  "FROM node:${new_node}-alpine${new_node_alpine}"

apply Dockerfile \
  '^FROM ferilagi/webserver:php[0-9]+\.[0-9]+\.[0-9]+' \
  "FROM ferilagi/webserver:php${new_php}"

apply build.sh \
  'ferilagi/webserver:php[0-9]+\.[0-9]+\.[0-9]+_node[0-9]+\.[0-9]+\.[0-9]+' \
  "ferilagi/webserver:php${new_php}_node${new_node}"

apply build.withoutNodejs.sh \
  'ferilagi/webserver:php[0-9]+\.[0-9]+\.[0-9]+' \
  "ferilagi/webserver:php${new_php}"

# README: baris "Based on php:..., node:..." ikut versi yang dipakai build
apply README.md \
  'Based on php:[0-9]+\.[0-9]+\.[0-9]+-fpm-alpine[0-9]+\.[0-9]+, node:[0-9]+\.[0-9]+\.[0-9]+-alpine[0-9]+\.[0-9]+' \
  "Based on php:${new_php}-fpm-alpine${new_php_alpine}, node:${new_node}-alpine${new_node_alpine}"

if [ "$DRY_RUN" != "1" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  echo
  echo "hasil perubahan:"
  git --no-pager diff --stat -- Dockerfile Dockerfile.withoutNodejs build.sh build.withoutNodejs.sh README.md
fi
