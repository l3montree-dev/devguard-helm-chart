---
# Concrete, machine-testable properties that define "secure coding" for this project.
# Each field is a claim that the checker will verify independently.

# SARIF reports proving SAST runs on the default branch.
# Machine check: same as SECURITY_SCANNING.md / sast_links.
evidences:
  # SAST reports (SARIF attested on each container image)
  - url: oci://ghcr.io/l3montree-dev/devguard:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://www.schemastore.org/schemas/json/sarif-2.1.0.json
  - url: oci://ghcr.io/l3montree-dev/devguard-web:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://www.schemastore.org/schemas/json/sarif-2.1.0.json
  - url: oci://ghcr.io/l3montree-dev/devguard/scanner:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://www.schemastore.org/schemas/json/sarif-2.1.0.json

  # Provenance attestations proving all release artifacts are signed and linked to a specific source commit and CI run.
  - url: oci://ghcr.io/l3montree-dev/devguard:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://slsa.dev/provenance/v1
  - url: oci://ghcr.io/l3montree-dev/devguard-web:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://slsa.dev/provenance/v1
  - url: oci://ghcr.io/l3montree-dev/devguard/scanner:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://slsa.dev/provenance/v1
---

# Secure Coding Standard

## What "secure coding" means for this project

Rather than citing a generic standard, the following concrete, verifiable properties define the secure coding baseline for DevGuard:

1. **All code changes go through a reviewed pull request** — the main branch is protected and requires at least one approving review before merge.
2. **SAST runs on every push** — semgrep scans all Go and TypeScript code. Merges are blocked on high-severity findings.
3. **Secret detection runs on every push** — Gitleaks scans for accidental credential exposure.
4. **All release artifacts are signed** — binaries and container images are signed with cosign. Signatures are verifiable using the public key in the repository.
5. **Build provenance is attested** — every release includes a provenance document (SLSA-compatible) linking the artifact to the exact source commit and CI pipeline run that produced it.
6. **Dependencies are pinned by digest** — all GitHub Actions and container images in CI are pinned to a SHA digest, not a mutable tag.

## Go-specific practices

- `CGO_ENABLED=0` for all production binaries (no C dependencies, reduced attack surface)
- Build flags: `-s -w -buildid=` to strip debug info and ensure reproducible builds
- `golangci-lint` with `gosec` rules enforced on every push

## Dependency management

All Go dependencies are tracked in `go.sum`. Node.js dependencies are locked via `package-lock.json`. Dependency scanning via DevGuard SCA runs on every push.