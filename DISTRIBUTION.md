# DevGuard Helm Chart Distribution

This repository includes automated workflows for distributing the DevGuard Helm chart to both GitHub and GitLab package registries.

## GitHub Actions Workflow

The GitHub Actions workflow (`.github/workflows/helm-release.yml`) automatically:

- **Triggers on**: Git tags starting with `v` (e.g., `v0.15.3`) or manual workflow dispatch
- **Packages**: The Helm chart with the specified version
- **Publishes**: To GitHub Container Registry (`ghcr.io`)
- **Creates**: GitHub releases with chart artifacts

### Usage

1. **Automatic release** (recommended):

   ```bash
   git tag v0.15.4
   git push origin v0.15.4
   ```

2. **Manual release**:
   - Go to Actions tab in GitHub
   - Select "Release Helm Chart" workflow
   - Click "Run workflow" and specify version

### Installing from GitHub Container Registry

```bash
# Add the repository
helm repo add devguard oci://ghcr.io/your-username

# Install the chart
helm install my-devguard oci://ghcr.io/your-username/devguard --version 0.15.3

# Or pull the chart
helm pull oci://ghcr.io/your-username/devguard --version 0.15.3
```

## GitHub Pages Helm Repository

Besides the OCI registry, the chart is published as a classic HTTP Helm repository on GitHub Pages: https://l3montree-dev.github.io/devguard-helm-chart

The workflow (`.github/workflows/helm-pages.yml`):

- **Triggers on**: a completed tag release (called by `helm-release.yml`), a push to `main` touching `artifacthub-repo.yml` or the landing page, or manual dispatch
- **Collects**: every `*.tgz` chart package and `*.tgz.prov` provenance file attached to the GitHub releases
- **Verifies**: every collected package against the committed public key before publishing
- **Generates**: `index.yaml` via `helm repo index --url <pages-url>`
- **Publishes**: `index.yaml`, all chart packages and provenance files, `signing-key.asc`, `artifacthub-repo.yml` and a landing page to GitHub Pages

The site is rebuilt from scratch on every run — the GitHub releases are the source of truth.

### Installing from the Helm repository

```bash
helm repo add devguard https://l3montree-dev.github.io/devguard-helm-chart
helm repo update
helm install devguard devguard/devguard
```

### Artifact Hub

`artifacthub-repo.yml` is copied next to `index.yaml` so [artifacthub.io](https://artifacthub.io) can read the repository metadata — this is what enables the ownership claim and the verified publisher flag. Set `repositoryID` in that file to the ID of the Artifact Hub repository to activate the verified publisher badge.

Note that Artifact Hub only reprocesses an HTTP Helm repository when `index.yaml` changes.

## Chart signing

Every released chart package is signed with OpenPGP, producing a `<chart>.tgz.prov`
provenance file next to it. That file is what `helm verify` checks, and it is also
what makes Artifact Hub show the **signed** badge — it probes `<chart-url>.prov` for
HTTP repositories and the `application/vnd.cncf.helm.chart.provenance.v1.prov` layer
for OCI ones. Note that Artifact Hub only checks that the file *exists* and looks
like a PGP signature; it does not validate it. The `artifacthub.io/signKey`
annotation does not affect the badge, it only tells users which key to verify against.

### One-time setup

1. Create a signing key (no expiry is fine for a chart signing key, but rotation is easier with one):

   ```bash
   gpg --quick-generate-key "DevGuard Chart Signing <info@l3montree.com>" rsa4096 sign 2y
   ```

2. Commit the public half — it is both the verification key for users and the source
   of the fingerprint and user ID that CI uses:

   ```bash
   gpg --armor --export "DevGuard Chart Signing" > .github/pages/signing-key.asc
   ```

3. Export the secret keyring. Helm signs with the legacy binary keyring format,
   which gpg ≥ 2.1 no longer keeps on disk, so it has to be exported explicitly:

   ```bash
   gpg --export-secret-keys "DevGuard Chart Signing" | base64 | tr -d '\n' | pbcopy
   ```

4. Add the repository secrets (Settings → Secrets and variables → Actions):

   | Secret | Contents |
   | --- | --- |
   | `GPG_KEYRING_BASE64` | output of step 3 |
   | `GPG_PASSPHRASE` | passphrase of the key (leave unset if the key has none) |

   Optionally set the `GPG_KEY_UID` **variable** if Helm's `--key` should match
   something other than the first user ID of the committed public key.

5. Verify the round trip locally before tagging a release:

   ```bash
   gpg --export-secret-keys "DevGuard Chart Signing" > /tmp/secring.gpg
   gpg --dearmor < .github/pages/signing-key.asc > /tmp/pubring.gpg

   helm package . --sign --key "DevGuard Chart Signing" --keyring /tmp/secring.gpg
   helm verify devguard-*.tgz --keyring /tmp/pubring.gpg
   ```

   Both `--keyring` flags need the *binary* keyring format — Helm reads it with
   `openpgp.ReadKeyRing`, which does not understand ASCII armor.

### What the release workflow does

`helm-release.yml` restores the keyring, injects `artifacthub.io/signKey`
(fingerprint plus the Pages URL of the public key) into `Chart.yaml`, packages with
`--sign`, verifies the result against the committed public key, and attaches both
the `.tgz` and the `.tgz.prov` to the GitHub release. `helm push` picks up the
provenance file automatically and uploads it as an OCI layer.

A **tagged** release fails hard if the keyring secret or the public key is missing —
the versions users actually install must never go out unsigned. Pushes to `main`
(the `0.0.0-main` package) only warn and publish unsigned.

### Verifying as a user

```bash
curl -sLO https://l3montree-dev.github.io/devguard-helm-chart/signing-key.asc
gpg --dearmor < signing-key.asc > signing-key.gpg

helm pull devguard/devguard --prov          # HTTP repository
helm pull oci://ghcr.io/l3montree-dev/devguard-helm-chart/devguard --prov   # OCI

helm verify devguard-*.tgz --keyring ./signing-key.gpg
```

`helm install --verify` does the same check inline, provided the keyring is in place.

### Rotation

Replace `.github/pages/signing-key.asc` and `GPG_KEYRING_BASE64` together. The Pages
job re-verifies *all* published packages on every run, so a mismatch between the
committed public key and the packages already released fails the deployment rather
than silently publishing unverifiable provenance files. Keep the old public key
appended to `signing-key.asc` (it is a keyring — it can hold several keys) so
previously released versions stay verifiable.

> Signing is not wired into `.gitlab-ci.yml`. The GitLab pipeline is a mirror and is
> not indexed by Artifact Hub; adding it needs the same two variables in GitLab CI/CD.

## GitLab CI Pipeline

The GitLab CI configuration (`.gitlab-ci.yml`) automatically:

- **Triggers on**: Git tags starting with `v` or manual pipeline runs
- **Lints**: Chart on merge requests and main branch
- **Packages**: The Helm chart with the specified version
- **Publishes**: To GitLab Container Registry
- **Creates**: GitLab releases (optional, requires `GITLAB_TOKEN`)

### Setup Requirements

For GitLab releases (optional), add a project access token:

1. Go to Project Settings → Access Tokens
2. Create token with `api` scope
3. Add as CI/CD variable named `GITLAB_TOKEN`

### Usage

1. **Automatic release**:

   ```bash
   git tag v0.15.4
   git push origin v0.15.4
   ```

2. **Manual release**:
   - Go to CI/CD → Pipelines
   - Click "Run pipeline"
   - The `helm-release` job can be triggered manually

### Installing from GitLab Container Registry

```bash
# Login to GitLab registry (if private)
helm registry login registry.gitlab.com --username your-username

# Install the chart
helm install my-devguard oci://registry.gitlab.com/your-group/devguard-helm-chart/devguard --version 0.15.3

# Or pull the chart
helm pull oci://registry.gitlab.com/your-group/devguard-helm-chart/devguard --version 0.15.3
```

## Version Management

Both workflows automatically:

- Extract version from Git tags (removing the `v` prefix)
- Update `Chart.yaml` with the correct version and appVersion
- Package the chart with the proper version

## Registry Permissions

### GitHub

- Uses `GITHUB_TOKEN` (automatically provided)
- Requires `packages: write` permission (included in workflow)

### GitLab

- Uses `CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD` (automatically provided)
- Works with GitLab Container Registry by default

## Chart Structure

The workflows expect the standard Helm chart structure:

```
Chart.yaml          # Chart metadata
values.yaml         # Default values
templates/          # Kubernetes templates
  _helpers.tpl      # Template helpers
  ...
```

## Troubleshooting

### Common Issues

1. **Authentication failures**: Ensure proper permissions are set for the repository
2. **Version conflicts**: Make sure tag versions match semantic versioning (e.g., `v1.2.3`)
3. **Registry limits**: Check registry storage limits if uploads fail

### Testing Locally

```bash
# Lint the chart
helm lint .

# Test template rendering
helm template test-release . --debug --dry-run

# Package locally
helm package .
```
