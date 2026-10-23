#!/usr/bin/env bash
# Refresh the pre-installed official partner-charts ClusterRepo (or register
# a custom git repo, see CHART_REPO_GIT in env.sh) and wait until Rancher has
# fetched and indexed it, then resolve/verify the chart version to install.
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

if [[ -z $CHART_REPO_GIT ]]; then
  # Rancher creates this repo itself on startup (pkg/data/dashboard/repo.go),
  # but builds the first index from the snapshot bundled in the rancher image
  # (which can predate the chart) and only fetches upstream on the next
  # refresh, by default after an hour. So wait for that first index, then
  # force a refresh — the same as "Refresh" in the UI.
  log "using pre-installed ClusterRepo $CHART_REPO_NAME"
  repo_exists() { kubectl get "clusterrepos.catalog.cattle.io/$CHART_REPO_NAME"; }
  wait_for 300 "ClusterRepo $CHART_REPO_NAME created by Rancher" repo_exists
  kubectl wait "clusterrepos.catalog.cattle.io/$CHART_REPO_NAME" --for=condition=Downloaded --timeout=600s
  log "bundled commit: $(kubectl get "clusterrepos.catalog.cattle.io/$CHART_REPO_NAME" -o jsonpath='{.status.commit}'), forcing refresh from upstream"
  kubectl patch "clusterrepos.catalog.cattle.io/$CHART_REPO_NAME" --type merge \
    -p "{\"spec\":{\"forceUpdate\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"
else
  log "creating ClusterRepo $CHART_REPO_NAME -> $CHART_REPO_GIT ($CHART_REPO_BRANCH)"
  kubectl apply -f - <<EOF
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: ${CHART_REPO_NAME}
spec:
  gitRepo: ${CHART_REPO_GIT}
  gitBranch: ${CHART_REPO_BRANCH}
EOF
fi

# Wait until Rancher has processed the current spec (including a forced
# refresh) and the download succeeded. The clone is large (assets/ + .git),
# allow plenty of time.
repo_synced() {
  kubectl get "clusterrepos.catalog.cattle.io/$CHART_REPO_NAME" -o json | jq -e '
    .status.observedGeneration == .metadata.generation and
    any(.status.conditions[]?; .type == "Downloaded" and .status == "True")'
}
wait_for 600 "ClusterRepo $CHART_REPO_NAME downloaded" repo_synced
kubectl get "clusterrepos.catalog.cattle.io/$CHART_REPO_NAME" \
  -o jsonpath='repo: {.spec.gitRepo} ({.spec.gitBranch}), commit: {.status.commit}{"\n"}'

INDEX=$(rapi GET "/v1/catalog.cattle.io.clusterrepos/$CHART_REPO_NAME?link=index")

if [[ -z $CHART_VERSION ]]; then
  CHART_VERSION=$(jq -r --arg c "$CHART_NAME" '.entries[$c][0].version // empty' <<<"$INDEX")
  [[ -n $CHART_VERSION ]] || die "chart '$CHART_NAME' not found in repo index"
  log "resolved latest chart version: $CHART_VERSION"
else
  jq -e --arg c "$CHART_NAME" --arg v "$CHART_VERSION" \
    '.entries[$c][] | select(.version == $v)' <<<"$INDEX" >/dev/null ||
    die "chart '$CHART_NAME' version '$CHART_VERSION' not found in repo index"
  log "chart $CHART_NAME $CHART_VERSION found in repo index"
fi
printf '%s' "$CHART_VERSION" >"$WORK_DIR/chart_version"
