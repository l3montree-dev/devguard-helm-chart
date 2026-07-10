#!/usr/bin/env bash
# Health checks: all workloads rolled out, no unhealthy pods, and the /health
# endpoints answer 200 — both through the chart's Ingress resources (via the
# port-forwarded ingress-nginx controller with Host headers) and directly
# against the services.
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

log "waiting for all workloads in $APP_NAMESPACE to roll out"
for w in $(kubectl -n "$APP_NAMESPACE" get deploy,statefulset -o name); do
  kubectl -n "$APP_NAMESPACE" rollout status "$w" --timeout=600s
done

kubectl -n "$APP_NAMESPACE" get pods -o wide
BAD=$(kubectl -n "$APP_NAMESPACE" get pods \
  --field-selector=status.phase!=Running,status.phase!=Succeeded -o name)
[[ -z $BAD ]] || die "unhealthy pods: $BAD"

PF_PIDS=()
cleanup() { kill "${PF_PIDS[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# port_forward <namespace> <svc> <local:remote>
port_forward() {
  kubectl -n "$1" port-forward "svc/$2" "$3" >/dev/null 2>&1 &
  PF_PIDS+=($!)
  wait_for 60 "port-forward $2 ($3)" curl -s -o /dev/null "http://127.0.0.1:${3%%:*}"
}

log "checking /health endpoints through the ingress"
port_forward ingress-nginx ingress-nginx-controller 8081:80
expect_200 "API via ingress ($API_INGRESS_HOST)" \
  "http://127.0.0.1:8081/api/v1/health" "$API_INGRESS_HOST"
expect_200 "web via ingress ($WEB_INGRESS_HOST)" \
  "http://127.0.0.1:8081/api/health" "$WEB_INGRESS_HOST"

log "checking /health endpoints directly on the services"
port_forward "$APP_NAMESPACE" devguard-api-service 18080:8080
expect_200 "API service" "http://127.0.0.1:18080/api/v1/health"
port_forward "$APP_NAMESPACE" devguard-web-service 13000:3000
expect_200 "web service" "http://127.0.0.1:13000/api/health"

log "smoke test passed"
