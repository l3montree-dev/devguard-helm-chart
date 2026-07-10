#!/usr/bin/env bash
# Install the chart through Rancher's catalog API — the same code path the
# dashboard uses (spawns a helm-operation pod in cattle-system).
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

[[ -z $CHART_VERSION && -f $WORK_DIR/chart_version ]] &&
  CHART_VERSION=$(cat "$WORK_DIR/chart_version")
[[ -n $CHART_VERSION ]] || die "CHART_VERSION not set (run 05-clusterrepo.sh first)"

log "preparing namespace $APP_NAMESPACE and required secrets"
kubectl create namespace "$APP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
# The chart defaults to api.github.enabled=true and mounts these secrets;
# dummies are enough for the deployment to start. (ec-private-key must NOT be
# pre-created — the chart templates it itself and helm refuses to adopt a
# non-helm-owned secret.)
for s in "github-app-webhook-secret webhookSecret" \
  "github-app-private-key privateKey"; do
  read -r name key <<<"$s"
  kubectl -n "$APP_NAMESPACE" create secret generic "$name" \
    --from-literal="$key=dummy" --dry-run=client -o yaml | kubectl apply -f -
done

VALUES=$(jq --arg ah "$API_INGRESS_HOST" --arg wh "$WEB_INGRESS_HOST" \
  '.api.ingress.host = $ah | .web.ingress.host = $wh' ci-values.json)

# Payload shape per ChartInstallAction (pkg/api/steve/catalog/types/rest.go).
# The ui-source-repo annotations are required for uninstall/upgrade to resolve
# the repo later. Do not add unknown top-level keys — they are passed through
# as raw helm CLI flags.
PAYLOAD=$(jq -n \
  --arg repo "$CHART_REPO_NAME" --arg chart "$CHART_NAME" --arg ver "$CHART_VERSION" \
  --arg rel "$RELEASE_NAME" --arg ns "$APP_NAMESPACE" --argjson values "$VALUES" '{
  charts: [{
    chartName: $chart,
    version: $ver,
    releaseName: $rel,
    annotations: {
      "catalog.cattle.io/ui-source-repo-type": "cluster",
      "catalog.cattle.io/ui-source-repo": $repo
    },
    values: $values
  }],
  wait: true,
  timeout: "600s",
  namespace: $ns,
  projectId: "",
  noHooks: false,
  disableOpenAPIValidation: false,
  skipCRDs: false
}')

log "installing $CHART_NAME $CHART_VERSION as release $RELEASE_NAME via catalog API"
RESP=$(rapi POST "/v1/catalog.cattle.io.clusterrepos/$CHART_REPO_NAME?action=install" -d "$PAYLOAD")
OP_NAME=$(jq -r '.operationName // empty' <<<"$RESP")
OP_NS=$(jq -r '.operationNamespace // empty' <<<"$RESP")
[[ -n $OP_NAME ]] || die "install action failed: $RESP"
log "operation: $OP_NS/$OP_NAME"

# The operation resource lives in the target namespace, but the pod it spawns
# runs elsewhere (cattle-system) — status.podNamespace is authoritative.
operation_status() {
  rapi GET "/v1/catalog.cattle.io.operations/$OP_NS/$OP_NAME" |
    jq -r '"\(.status.podNamespace // "")/\(.status.podName // "")"'
}
pod_exists() { [[ $(operation_status) != */ ]]; }
wait_for 120 "helm-operation pod scheduled" pod_exists
IFS=/ read -r POD_NS POD <<<"$(operation_status)"

pod_started() {
  local phase
  phase=$(kubectl -n "$POD_NS" get pod "$POD" -o jsonpath='{.status.phase}')
  [[ $phase == Running || $phase == Succeeded || $phase == Failed ]]
}
wait_for 300 "helm-operation pod started (pulls rancher/shell on first use)" pod_started

log "streaming helm output from pod $POD_NS/$POD"
kubectl -n "$POD_NS" logs -f "$POD" -c helm || true

# helm runs with --wait --timeout 600s, so pod completion == release readiness
# (or failure). Give it the full budget plus image-pull slack.
pod_finished() {
  local phase
  phase=$(kubectl -n "$POD_NS" get pod "$POD" -o jsonpath='{.status.phase}')
  [[ $phase == Succeeded || $phase == Failed ]]
}
wait_for 900 "helm-operation pod finished" pod_finished
PHASE=$(kubectl -n "$POD_NS" get pod "$POD" -o jsonpath='{.status.phase}')
[[ $PHASE == Succeeded ]] || die "helm operation ended in phase $PHASE"

app_deployed() {
  kubectl -n "$APP_NAMESPACE" get "apps.catalog.cattle.io/$RELEASE_NAME" \
    -o jsonpath='{.spec.info.status}' | grep -qx deployed
}
wait_for 120 "app $RELEASE_NAME reports deployed" app_deployed
log "release $RELEASE_NAME deployed"
