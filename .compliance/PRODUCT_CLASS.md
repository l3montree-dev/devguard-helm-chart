---
# Whether this project is subject to the CRA (Artikel 2).
# Machine check: if false, all other compliance checks are skipped.
cra_applicable: true

# CRA product class as defined in Anhang III.
# Machine check: if class is 2, a third-party audit document is expected.
# Allowed values: 1, 2
class: 1
---

# Product Classification

DevGuard is a software supply chain security platform. It performs vulnerability scanning, manages SBOMs and provenance attestations, and provides compliance dashboards for development teams.

The product handles security-sensitive data (CVE findings, access tokens, deployment metadata) and is used in contexts where integrity and availability are business-critical. It is classified as **class 1** under Anhang III of the CRA.

The product spans multiple components deployed together via this Helm chart:

- **devguard** — the backend API (Go)
- **devguard-web** — the frontend (Next.js)
- **devguard-scanner** — the CLI scanning tool (Go)
- **devguard-action** — the GitHub Actions integration
- **devguard-ci-component** — the GitLab CI component (`gitlab.opencode.de/l3montree/devguard-ci-components`)

Each component is released independently but versioned together in this Helm chart.
