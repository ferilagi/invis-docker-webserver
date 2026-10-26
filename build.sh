#!/bin/bash

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t ferilagi/webserver:php8.4.27_node26.12.1 \
    -t ferilagi/webserver:latest \
    --push .