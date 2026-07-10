#!/usr/bin/env bash
# Uninstall the release through Rancher's catalog API and wait for the App
# resource to disappear.
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

log "uninstalling $RELEASE_NAME via catalog API"
rapi POST "/v1/catalog.cattle.io.apps/$APP_NAMESPACE/$RELEASE_NAME?action=uninstall" \
  -d '{}' >/dev/null

app_gone() {
  ! kubectl -n "$APP_NAMESPACE" get "apps.catalog.cattle.io/$RELEASE_NAME" 2>/dev/null
}
wait_for 300 "app $RELEASE_NAME removed" app_gone
kubectl -n "$APP_NAMESPACE" get pods || true
log "uninstall complete"
