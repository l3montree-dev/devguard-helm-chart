---
# SBOM artifact entries. Each entry has a url and an optional cosign_public_key_url.
# Machine check:
#   https:// url → HTTP GET → assert 200, parse as valid CycloneDX JSON
#   oci:// url   → cosign verify-attestation --type cyclonedx <ref> --key <cosign_public_key_url>
evidences:
  - url: https://github.com/l3montree-dev/devguard/releases/tag/v1.1.0
  - url: oci://ghcr.io/l3montree-dev/devguard:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://cyclonedx.org/bom
  - url: oci://ghcr.io/l3montree-dev/devguard-web:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://cyclonedx.org/bom
  - url: oci://ghcr.io/l3montree-dev/devguard/scanner:latest
    cosign_public_key_url: https://raw.githubusercontent.com/l3montree-dev/devguard/main/cosign.pub
    predicate_type: https://cyclonedx.org/bom

---

# Software Bill of Materials

An SBOM is generated for every release of the DevGuard scanner binaries and container images. The SBOM documents all direct and transitive dependencies, their versions, and known licenses.

**Binary SBOMs** are currently **NOT** produced. This will be added in a future release.

**Container image SBOMs** are embedded as OCI referrers using cosign attestations. This allows any consumer of the image to verify the SBOM directly from the registry without relying on a separate download link. The attestations are signed with the project's cosign key.