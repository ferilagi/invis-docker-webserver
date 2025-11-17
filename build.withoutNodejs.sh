#!/bin/bash

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -f Dockerfile.withoutNodejs \
    -t ferilagi/webserver:php8.4.14 \
    --push .
