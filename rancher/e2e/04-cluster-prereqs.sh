#!/usr/bin/env bash
# The embedded k3s runs with --disable=traefik,servicelb,metrics-server,local-storage
# so the cluster has no StorageClass and no ingress controller. Install
# local-path-provisioner and ingress-nginx (baremetal manifest: NodePort —
# hostPort 80/443 would collide with the rancher process, servicelb is off).
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
source ./lib.sh

log "installing local-path-provisioner"
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.36/deploy/local-path-storage.yaml
kubectl -n local-path-storage rollout status deploy/local-path-provisioner --timeout=180s

log "installing ingress-nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.0/deploy/static/provider/baremetal/deploy.yaml
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s

# The chart's NetworkPolicies (networkPolicy.enabled=true by default, enforced
# here by the embedded k3s's kube-router) only admit ingress traffic from a
# namespace labelled role=ingress — see networkPolicy.ingressNamespaceSelector*
# in the chart values. Without this label the controller gets connection-refused
# and every request returns 502.
kubectl label namespace ingress-nginx role=ingress --overwrite
# The admission webhook must be usable before the chart's Ingress objects are
# created, otherwise the helm install fails with "failed calling webhook".
# (The admission jobs self-delete via ttlSecondsAfterFinished, so waiting on
# them is racy — a server-side dry-run Ingress proves the webhook works.)
webhook_ready() {
  kubectl create --dry-run=server -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: e2e-admission-canary
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: canary.local.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: canary
                port:
                  number: 80
EOF
}
wait_for 180 "ingress-nginx admission webhook ready" webhook_ready
