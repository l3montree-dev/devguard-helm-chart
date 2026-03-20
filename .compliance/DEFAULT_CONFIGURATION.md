---
# All resources that define or implement the default deployment configuration.
# Protocols:
#   file://  — IaC files in this repo (machine check: assert path exists, scan for secrets/misconfigs)
#   oci://   — container images deployed by this chart
#   https:// — source references (Dockerfiles, chart source)
evidences:
  # IaC files
  - url: file://values.yaml
  - url: file://templates/networkpolicy.yaml
  - url: file://templates/kyverno-policy.yaml
  # Container images
  - url: oci://ghcr.io/l3montree-dev/devguard
  - url: oci://ghcr.io/l3montree-dev/devguard-web
  - url: oci://ghcr.io/l3montree-dev/devguard/postgresql
  # Source references
  - url: https://github.com/l3montree-dev/devguard-helm-chart/blob/main/values.yaml
  - url: https://github.com/l3montree-dev/devguard-helm-chart/blob/main/templates/networkpolicy.yaml
  - url: https://github.com/l3montree-dev/devguard-helm-chart/blob/main/templates/kyverno-policy.yaml
  - url: https://github.com/l3montree-dev/devguard/blob/main/Dockerfile
  - url: https://github.com/l3montree-dev/devguard-web/blob/main/Dockerfile
  - url: https://github.com/l3montree-dev/devguard/blob/main/postgresql/Dockerfile
---

# Default Configuration

The DevGuard Helm chart ships with secure defaults out of the box.

## Secrets Management

No secrets are hardcoded in the chart. All sensitive values (database passwords, SMTP credentials, CSAF keys, API tokens) are referenced via `existingSecretName` fields, requiring operators to provide Kubernetes Secrets before deployment. The chart never generates default credentials.

## Network Policies

A `NetworkPolicy` is included and enabled by default (`networkPolicy.enabled: true`). It restricts ingress and egress to only the necessary service-to-service communication paths within the cluster.

## Kyverno Policy

An optional Kyverno policy (`kyvernoPolicy.enabled`) enforces pod security standards at the cluster level. In `Enforce` mode it blocks non-compliant pods; in `Audit` mode it logs violations.

## Container Security

All DevGuard container images run as non-root users. The base images use distroless or minimal Alpine variants to reduce the attack surface.
