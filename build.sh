#!/bin/bash

docker build \
    --build-arg APKMIRROR="turbo.net.id" \
    -t ferilagi/invis:nginx_php_node .
