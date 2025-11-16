#!/bin/bash

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t ferilagi/webserver:php8.4-node24 \
    -t ferilagi/webserver:latest \
    --push .

