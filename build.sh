#!/bin/bash

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t ferilagi/webserver:php8.4.14_node25.1 \
    -t ferilagi/webserver:latest \
    --push .