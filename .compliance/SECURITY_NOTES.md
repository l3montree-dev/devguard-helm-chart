---
# URLs to public user-facing security documentation.
# Machine check: HTTP GET each url → assert 200,
# assert content-type is text/html or application/pdf.
evidences:
  - url: https://docs.devguard.org
  - url: https://docs.devguard.org/self-hosting
---

# Security Notes for Users

## Self-hosting

DevGuard is designed to be self-hosted. The Helm chart is the recommended deployment method. Security-relevant configuration options are documented at https://docs.devguard.org/self-hosting.

Key operator responsibilities:

- **TLS certificates**: Provide a valid certificate via cert-manager or equivalent. Do not expose the API or frontend over plain HTTP.
- **Secret management**: All credentials must be provided as Kubernetes Secrets before deployment. The chart has no default passwords.
- **Network policies**: Enable `networkPolicy.enabled: true` in production to restrict pod-to-pod traffic.
- **Updates**: Follow the `:unstable` tag for the latest security patches, or subscribe to GitHub release notifications for versioned releases.

## Reporting Security Issues

See [SECURITY.md](./SECURITY.md) for the vulnerability disclosure process.
