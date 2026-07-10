#!/usr/bin/env bash
# Dump everything useful for debugging a failed run. Never fails itself.
set -uo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

section() { printf '\n===== %s =====\n' "$*"; }

section "rancher container logs (last 300 lines)"
docker logs --tail 300 "$(rancher_container)" 2>&1 || true

section "df -h"
df -h || true

if [[ -f $KUBECONFIG ]]; then
  section "nodes / storageclasses / clusterrepos"
  kubectl get nodes,storageclasses -o wide || true
  kubectl get clusterrepos.catalog.cattle.io -o wide || true
  kubectl describe clusterrepos.catalog.cattle.io "$CHART_REPO_NAME" || true

  for ns in cattle-system "$APP_NAMESPACE" ingress-nginx local-path-storage; do
    section "pods and events in $ns"
    kubectl -n "$ns" get pods -o wide || true
    kubectl -n "$ns" get events --sort-by=.lastTimestamp | tail -30 || true
  done

  section "helm-operation pod logs"
  for ns in cattle-system "$APP_NAMESPACE"; do
    for pod in $(kubectl -n "$ns" get pods -o name | grep helm-operation); do
      echo "--- $ns/$pod"
      kubectl -n "$ns" logs "$pod" -c helm --tail 100 || true
    done
  done

  section "app resource, pvcs, ingresses in $APP_NAMESPACE"
  kubectl -n "$APP_NAMESPACE" get "apps.catalog.cattle.io/$RELEASE_NAME" -o yaml || true
  kubectl -n "$APP_NAMESPACE" describe pvc || true
  kubectl -n "$APP_NAMESPACE" get ingress -o wide || true

  section "describe non-running pods in $APP_NAMESPACE"
  for pod in $(kubectl -n "$APP_NAMESPACE" get pods \
    --field-selector=status.phase!=Running,status.phase!=Succeeded -o name); do
    kubectl -n "$APP_NAMESPACE" describe "$pod" || true
    kubectl -n "$APP_NAMESPACE" logs "$pod" --all-containers --tail 50 || true
  done
else
  section "no kubeconfig yet ($KUBECONFIG missing) — bootstrap did not complete"
fi

exit 0
