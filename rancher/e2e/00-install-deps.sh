#!/usr/bin/env bash
# Install the tools the e2e scripts need, for running the suite locally inside a
# fresh Linux VM (see ../Rancher-Setup.md). A `orb create ubuntu` VM only ships
# curl; this adds Docker (bring-up) and jq + kubectl (bootstrap/prereqs).
#
# Not used in CI: there Docker and jq come from the GitHub runner and kubectl
# from the azure/setup-kubectl step (see ../../.github/workflows/rancher-catalog-test.yaml).
# Idempotent — skips anything already present.
set -euo pipefail

# Match the k3s version embedded in rancher 2.14 (kept in sync with the
# azure/setup-kubectl version in rancher-catalog-test.yaml).
: "${KUBECTL_VERSION:=v1.35.0}"

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

if command -v docker >/dev/null 2>&1; then
  log "docker already installed ($(docker --version))"
else
  log "installing docker"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$(whoami)"
  log "added $(whoami) to the docker group — log out/in (or reconnect the VM) for it to take effect"
fi

if command -v jq >/dev/null 2>&1; then
  log "jq already installed ($(jq --version))"
else
  log "installing jq"
  sudo apt-get update -qq
  sudo apt-get install -y -qq jq
fi

if command -v kubectl >/dev/null 2>&1; then
  log "kubectl already installed ($(kubectl version --client -o json | jq -r .clientVersion.gitVersion))"
else
  log "installing kubectl $KUBECTL_VERSION"
  curl -fsSLo /tmp/kubectl \
    "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$(dpkg --print-architecture)/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
fi

log "dependencies ready"
