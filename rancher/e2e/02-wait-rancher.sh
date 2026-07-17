#!/usr/bin/env bash
# Wait until the Rancher API answers on /healthz.
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

wait_for 300 "Rancher /healthz at $RANCHER_URL" curl -skf "$RANCHER_URL/healthz"
