#!/usr/bin/env bash
# Headless Rancher bootstrap: login, set admin password + server-url, fetch a
# kubeconfig for the embedded "local" cluster, wait for it to be usable.
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

login() {
  curl -sk -X POST "$RANCHER_URL/v3-public/localProviders/local?action=login" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"admin\",\"password\":\"$1\",\"responseType\":\"json\"}" |
    jq -r '.token // empty'
}

# The admin user is created asynchronously after /healthz goes green, so poll.
# Try the admin password first (re-runs against an already-bootstrapped
# instance), then the bootstrap password (first run).
TOKEN="" FIRST_LOGIN=""
deadline=$((SECONDS + 480))
log "logging in (polling until the local auth provider is ready)"
while [[ -z $TOKEN ]]; do
  TOKEN=$(login "$RANCHER_ADMIN_PASSWORD")
  if [[ -z $TOKEN ]]; then
    TOKEN=$(login "$CATTLE_BOOTSTRAP_PASSWORD")
    [[ -n $TOKEN ]] && FIRST_LOGIN=1
  fi
  if [[ -z $TOKEN ]]; then
    ((SECONDS >= deadline)) && die "could not log in to Rancher within 480s"
    sleep 5
  fi
done
umask 077
printf '%s' "$TOKEN" >"$WORK_DIR/token"
log "logged in${FIRST_LOGIN:+ (first login, with bootstrap password)}"

if [[ -n $FIRST_LOGIN ]]; then
  log "setting admin password"
  rapi POST "/v3/users?action=changepassword" -d "{
    \"currentPassword\": \"$CATTLE_BOOTSTRAP_PASSWORD\",
    \"newPassword\": \"$RANCHER_ADMIN_PASSWORD\"
  }" >/dev/null
fi

log "setting server-url to $RANCHER_URL"
rapi PUT "/v3/settings/server-url" \
  -d "{\"name\":\"server-url\",\"value\":\"$RANCHER_URL\"}" >/dev/null

cluster_active() { rapi GET /v3/clusters/local | jq -e '.state == "active"'; }
wait_for 480 "local cluster active" cluster_active

log "generating kubeconfig for the local cluster"
rapi POST "/v3/clusters/local?action=generateKubeconfig" | jq -r .config >"$KUBECONFIG"
# Self-signed cert whose SANs don't cover 127.0.0.1 — same workaround as in
# ../Rancher-Setup.md.
kubectl config unset clusters.local.certificate-authority-data >/dev/null
kubectl config set-cluster local --insecure-skip-tls-verify=true >/dev/null

wait_for 120 "kubectl reaches the local cluster" kubectl get nodes
kubectl get nodes

# The first helm operation needs the rancher webhook to be up.
wait_for 300 "rancher-webhook deployment exists" \
  kubectl -n cattle-system get deploy rancher-webhook
kubectl -n cattle-system rollout status deploy/rancher-webhook --timeout=300s
