#!/bin/bash

docker build \
    --build-arg APKMIRROR="turbo.net.id" \
    -f Dockerfile.withoutNodejs \
    -t ferilagi/invis:nginx_php .
