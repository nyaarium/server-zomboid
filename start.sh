#!/bin/bash

set -e
cd "$(dirname "$0")"

# Ensure data directories exist
mkdir -p data/zomboid data/workshop

# First positional selects the service explicitly. The orchestrator
# (server-config.json5) always passes one of these.
mode="${1:-}"
shift || true

case "$mode" in
    game)
        # Long-lived game server: build + start the app container, then attach.
        docker compose up -d --build
        exec docker exec -i app /app/docker-entrypoint.sh
        ;;
    *)
        echo "Usage: start.sh {game}" >&2
        exit 2
        ;;
esac
