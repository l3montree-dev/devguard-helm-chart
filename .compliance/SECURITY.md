---
# Public security contact for vulnerability disclosures.
# Machine check: assert valid email address format.
evidences:
  - contact: developer@l3montree.com
    pgp_key_url: https://l3montree.com/developer@l3montree.com-0xA71508222B6168D5-pub.asc
---

# Vulnerability Disclosure Policy

Security vulnerabilities can be reported via **GitHub Private Vulnerability Reporting** at:
https://github.com/l3montree-dev/devguard/security/advisories/new

Maintainers are notified privately. Once a fix is available, the report is made public as part of a coordinated disclosure. Reporters may be credited if they wish.

Alternatively, reports can be sent to `developer@l3montree.com`, encrypted with the PGP key above. This initiates a Coordinated Vulnerability Disclosure (CVD) process. The team aims to provide a patch within one week for critical issues.

## Response SLAs

| Severity (CVSS)    | Acknowledgement | Patch target |
|--------------------|-----------------|--------------|
| Critical (9.0–10.0) | 24 hours        | 72 hours     |
| High (7.0–8.9)      | 48 hours        | 7 days       |
| Medium (4.0–6.9)    | 7 days          | 30 days      |

## Supported Versions

The `:latest` tag always receives the latest security patches. For production, use a versioned tag. Patches for older versioned tags are only released for severe vulnerabilities.