#!/usr/bin/env bash
# Tear down the Rancher container and its state.
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

if [[ -f $RANCHER_STATE_DIR/compose.yml ]]; then
  docker compose -p "$COMPOSE_PROJECT" -f "$RANCHER_STATE_DIR/compose.yml" down -v || true
fi
# Rancher writes ./data as root; fall back to sudo where needed.
rm -rf "$RANCHER_STATE_DIR" 2>/dev/null || sudo rm -rf "$RANCHER_STATE_DIR" || true
rm -rf "$WORK_DIR"
log "teardown complete"
