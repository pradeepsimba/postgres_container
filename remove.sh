#!/bin/bash
set -e
# Same reasoning as clear.sh: without this, running the script from any other directory makes
# `docker compose down` fail with "no configuration file provided" instead of actually stopping
# the container - deploy.sh already does this same cd.
cd "$(dirname "$0")"

docker compose down
