#!/bin/bash

docker build \
    --build-arg APKMIRROR="turbo.net.id" \
    -t ferilagi/invis:nginx_php_node .


docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t ferilagi/webserver:php8.4-node24 \
    -t ferilagi/webserver:latest \
    --push .

