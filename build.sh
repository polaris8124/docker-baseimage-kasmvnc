#!/bin/sh

docker build --pull --no-cache -t gitea.polaris.ovh/polaris/image-base-kasm:polaris-ubuntu-noble-latest .
docker push gitea.polaris.ovh/polaris/image-base-kasm:polaris-ubuntu-noble-latest
