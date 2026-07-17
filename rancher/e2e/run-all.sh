#!/usr/bin/env bash
# Full Rancher catalog e2e test. Runs identically in GitHub Actions and
# locally (inside a Linux VM — see README.md). Diagnostics are collected
# automatically on failure; teardown is left to the caller (99-down.sh).
set -euo pipefail
cd "$(dirname "$0")"

trap 'echo "E2E FAILED — collecting diagnostics"; bash 90-diagnostics.sh' ERR

bash 01-up.sh
bash 02-wait-rancher.sh
bash 03-bootstrap.sh
bash 04-cluster-prereqs.sh
bash 05-clusterrepo.sh
bash 06-install.sh
bash 07-smoke.sh
if [[ ${SKIP_UNINSTALL:-0} != 1 ]]; then
  bash 08-uninstall.sh
fi

echo
echo "E2E PASSED"
