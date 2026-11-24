#!/usr/bin/env bash
# Cetak versi base image yang dipakai repo sekarang (dibaca dari Dockerfile).
#
# Pakai:
#   eval "$(bash scripts/security/current-versions.sh)"
#   echo "$PHP_VERSION / $NODE_VERSION"
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

php_from="$(grep -m1 -E '^FROM php:' Dockerfile.withoutNodejs | tr -d '\r')"
node_from="$(grep -m1 -E '^FROM node:' Dockerfile | tr -d '\r')"

PHP_VERSION="$(printf '%s' "$php_from" | sed -E 's/^FROM php:([0-9]+\.[0-9]+\.[0-9]+)-fpm-alpine.*/\1/')"
PHP_ALPINE="$(printf '%s' "$php_from" | sed -E 's/^FROM php:[0-9]+\.[0-9]+\.[0-9]+-fpm-alpine([0-9]+\.[0-9]+).*/\1/')"
NODE_VERSION="$(printf '%s' "$node_from" | sed -E 's/^FROM node:([0-9]+\.[0-9]+\.[0-9]+)-alpine.*/\1/')"
NODE_ALPINE="$(printf '%s' "$node_from" | sed -E 's/^FROM node:[0-9]+\.[0-9]+\.[0-9]+-alpine([0-9]+\.[0-9]+).*/\1/')"

for var in PHP_VERSION PHP_ALPINE NODE_VERSION NODE_ALPINE; do
  case "${!var}" in
    [0-9]*) ;;
    *)
      echo "gagal membaca $var dari Dockerfile/Dockerfile.withoutNodejs" >&2
      exit 1
      ;;
  esac
done

cat <<EOF
PHP_VERSION=$PHP_VERSION
PHP_ALPINE=$PHP_ALPINE
PHP_IMAGE_TAG=php$PHP_VERSION
PHP_FULL_TAG=$PHP_VERSION-fpm-alpine$PHP_ALPINE
NODE_VERSION=$NODE_VERSION
NODE_ALPINE=$NODE_ALPINE
NODE_FULL_TAG=$NODE_VERSION-alpine$NODE_ALPINE
PHP_NODE_IMAGE_TAG=php${PHP_VERSION}_node$NODE_VERSION
EOF
