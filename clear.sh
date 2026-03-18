#!/bin/bash
read -p "This will DELETE all PostgreSQL data. Are you sure? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    docker compose down
    rm -rf ./data
    echo "Container removed and all data deleted."
else
    echo "Aborted."
fi
