#!/bin/bash
set -e
# Without this, running the script from anywhere other than this exact directory (e.g.
# `bash postgres_container/clear.sh` from the algo workspace root, which is a natural thing to do
# in a multi-project workspace) makes `docker compose down` fail with "no configuration file
# provided" - and without set -e, that failure was silent, falling straight through to
# `rm -rf ./data`, which then deletes whatever ./data resolves to in the CALLER's cwd (potentially
# an unrelated sibling project's data folder) while the real Postgres container was never actually
# stopped, then still prints the false "Container removed and all data deleted." deploy.sh already
# does this same cd - this script and remove.sh were the two that didn't.
cd "$(dirname "$0")"

read -p "This will DELETE all PostgreSQL data. Are you sure? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    docker compose down
    rm -rf ./data
    echo "Container removed and all data deleted."
else
    echo "Aborted."
fi
