#!/usr/bin/env bash
# Start the Rancher container. compose.yml is copied to RANCHER_STATE_DIR so
# the ./data bind mounts land on a native filesystem (see ../Rancher-Setup.md).
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

mkdir -p "$RANCHER_STATE_DIR"
cp ../compose.yml "$RANCHER_STATE_DIR/compose.yml"

log "starting Rancher via docker compose (state dir: $RANCHER_STATE_DIR)"
docker compose -p "$COMPOSE_PROJECT" -f "$RANCHER_STATE_DIR/compose.yml" up -d --quiet-pull

docker compose -p "$COMPOSE_PROJECT" -f "$RANCHER_STATE_DIR/compose.yml" ps
