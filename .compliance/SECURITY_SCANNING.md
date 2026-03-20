---
# All scanning evidence is attested on container images via cosign.
# Machine check: cosign verify-attestation <ref> --key <cosign_public_key_url> --type <predicate_type>
# For SARIF: assert no findings with level: error.
# For VEX: assert all listed vulnerabilities have an explicit exploitability statement.
evidences:
  # SAST — SARIF attested on each container image
  - url: oci://ghcr.io/l3montree-dev/devguard:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://www.schemastore.org/schemas/json/sarif-2.1.0.json
  - url: oci://ghcr.io/l3montree-dev/devguard-web:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://www.schemastore.org/schemas/json/sarif-2.1.0.json
  - url: oci://ghcr.io/l3montree-dev/devguard/scanner:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://www.schemastore.org/schemas/json/sarif-2.1.0.json
  # VEX — exploitability statements attested on each container image
  - url: oci://ghcr.io/l3montree-dev/devguard:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://cyclonedx.org/vex
  - url: oci://ghcr.io/l3montree-dev/devguard-web:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://cyclonedx.org/vex
  - url: oci://ghcr.io/l3montree-dev/devguard/scanner:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://cyclonedx.org/vex
---

# Security Scanning

DevGuard scans itself using its own CI pipeline — dogfooding the same workflows it provides to other projects.

## SAST

Static analysis is performed by **semgrep** on every push via the `devguard-action` reusable workflow. Findings are uploaded to GitHub Code Scanning. The pipeline blocks merges when high-severity findings are present (`fail-on-risk: high`).

Go code is additionally linted with **golangci-lint** on every push, which catches common security anti-patterns (e.g. `gosec` rules).

## Dependency Scanning (SCA)

Software Composition Analysis runs on every push via the `devguard-action` SCA workflow. It scans all Go modules and Node.js packages for known CVEs. The pipeline fails on high-severity CVEs.

Results are visible at the DevGuard security dashboard:
https://main.devguard.org/l3montree-cybersecurity/projects/devguard/assets/devguard

## Secret Detection

Gitleaks runs on every push as part of the `devguard-action` secret-scanning workflow. A baseline file (`leaks-baseline.json`) suppresses known false positives.

## Container Scanning

Container images are scanned for known CVEs after every build via the `devguard-action` container-scanning workflow. The pipeline fails on high CVSS score findings.