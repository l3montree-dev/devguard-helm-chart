# Shared configuration for the Rancher catalog e2e test.
# Every value can be overridden via the environment (CI passes
# workflow_dispatch inputs this way). Source this before lib.sh.

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${RANCHER_URL:=https://127.0.0.1:8443}"
# Bootstrap password is seeded via CATTLE_BOOTSTRAP_PASSWORD in compose.yml
# (must be >= 12 characters). The admin password replaces it on first login.
: "${CATTLE_BOOTSTRAP_PASSWORD:=devguard-ci-bootstrap-pw}"
: "${RANCHER_ADMIN_PASSWORD:=devguard-ci-admin-pw}"

# Empty = use the official partner-charts repo that Rancher pre-installs as
# ClusterRepo "rancher-partner-charts" (https://github.com/rancher/partner-charts,
# branch main). Set it to register a separate ClusterRepo instead, e.g. the
# fork https://github.com/l3montree-dev/rancher-partner-charts.git with
# CHART_REPO_BRANCH=main-source to test a version before it is merged upstream.
: "${CHART_REPO_GIT:=}"
: "${CHART_REPO_BRANCH:=main}"
if [[ -z $CHART_REPO_GIT ]]; then
  : "${CHART_REPO_NAME:=rancher-partner-charts}"
else
  : "${CHART_REPO_NAME:=devguard-partner-charts}"
fi
: "${CHART_NAME:=devguard}"
# Empty = install the latest version found in the repo index.
: "${CHART_VERSION:=}"

: "${APP_NAMESPACE:=devguard}"
: "${RELEASE_NAME:=devguard}"
: "${API_INGRESS_HOST:=api.devguard.local.test}"
: "${WEB_INGRESS_HOST:=devguard.local.test}"

# Rancher's k3s data must live on a native filesystem (not a virtiofs mount,
# see ../Rancher-Setup.md), so compose.yml is copied here before starting.
: "${RANCHER_STATE_DIR:=$HOME/.local/state/devguard-rancher-e2e}"
: "${COMPOSE_PROJECT:=devguard-rancher-e2e}"

# Scratch dir for kubeconfig, API token and resolved chart version.
: "${WORK_DIR:=$E2E_DIR/.work}"
mkdir -p "$WORK_DIR"

export KUBECONFIG="$WORK_DIR/kubeconfig"
export CATTLE_BOOTSTRAP_PASSWORD
