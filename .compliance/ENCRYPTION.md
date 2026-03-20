---
# All resources relevant to encryption configuration.
# Protocols:
#   file://  — files in this repo (machine check: assert path exists, scan for TLS/encryption markers)
#   oci://   — container images deployed by this chart
#   https:// — source references (GitHub)
#
# TLS config files are scanned for minimum TLS version markers (e.g. "TLSv1.2", "ssl_protocols",
# "minProtocolVersion") — any config allowing TLS < 1.2 fails.
# At-rest config files are scanned for encryption indicators
# (e.g. "storage_encrypted", "kms_key_id", "encrypt: true", "sslmode=require").
evidences:
  # TLS (in-transit) config
  - url: file://templates/devguard/ingress.yaml
  - url: file://templates/devguard-web/ingress.yaml
  # At-rest encryption config
  - url: file://templates/postgresql/postgresql-statefulset.yaml
  # Source references
  - url: https://github.com/l3montree-dev/devguard-helm-chart/blob/main/templates/devguard/ingress.yaml
  - url: https://github.com/l3montree-dev/devguard-helm-chart/blob/main/templates/devguard-web/ingress.yaml
  - url: https://github.com/l3montree-dev/devguard-helm-chart/blob/main/templates/postgresql/postgresql-statefulset.yaml
---

# Encryption

## In Transit

All communication between clients and the DevGuard API and web frontend is encrypted via TLS 1.2 or higher, enforced at the Kubernetes Ingress level. The Helm chart ships Ingress templates with annotations that configure TLS termination. **Operators are expected to provide a valid TLS certificate (e.g. via cert-manager).**

Internal cluster communication between the API and the database does not use TLS. It is advised, that operators are using a service-mesh (e.g. Linkerd, Istio) to encrypt this traffic in transit, or deploy the database on a private network with no external access.

## At Rest

The PostgreSQL database is deployed without SSL enforced. Sensitive fields (API tokens, secrets) are stored hashed or encrypted at the application layer before being written to the database. Operators deploying on managed cloud databases should enable storage encryption at the infrastructure level (e.g. encrypted EBS volumes, RDS encryption).

