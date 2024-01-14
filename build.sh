#!/bin/sh

docker build --pull --no-cache -t registry.polaris.ovh/image-base-kasm:polaris-ubuntu-noble-latest .
docker push registry.polaris.ovh/image-base-kasm:polaris-ubuntu-noble-latest
