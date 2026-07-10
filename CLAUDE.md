# DevGuard Helm Chart

Helm chart for **DevGuard** (open-source software supply-chain security, vulnerability
management, compliance). Deploys the API (`devguard`), web frontend (`devguard-web`),
the Ory Kratos identity server, and a bundled PostgreSQL, plus optional observability
(ServiceMonitor, Grafana dashboards, OTel tracing) and Kyverno policies.

The chart is also published as a **Rancher partner chart**, which shapes several design
decisions (see _Rancher constraints_ below).

## ⚠️ The single most important rule

`values.yaml`, the Rancher `questions.yaml`, and the `version`/`appVersion` in
`Chart.yaml` are **generated** from [`schema/schema.ts`](schema/schema.ts). That file is
the single source of truth.

- **Never hand-edit `values.yaml` or `questions.yaml`.** Edit `schema/schema.ts` and regenerate.
- The top of each generated file says `# DO NOT EDIT`.
- CI (`schema-check`) fails the build if the generated files are out of sync.

```bash
cd schema
bun install          # bun is the runtime; deps are just `yaml`
bun run generate     # writes values.yaml, Chart.yaml (version/appVersion), and the partner questions.yaml
bun run check        # same as CI: exit 1 if any output is stale
```

### How the generator works

- `schema/schema.ts` is one nested tree. Plain values render straight into `values.yaml`.
  Wrap a value in `f(value, opts)` (from [`schema/builder.ts`](schema/builder.ts)) to attach:
  - `comment` (block comment before the key), `inline` (comment after the value),
    `trailingComment`, `blankBefore` (blank line), and `question` (Rancher form metadata).
- `banner("Title")` renders a section header comment.
- `devguardVersion` is the **one version knob**: it sets the api/web/postgresql image tags
  (`v`-prefixed) and `Chart.yaml`'s `version` (as-is) + `appVersion` (`v`-prefixed, quoted).
  Bump it there, not in `values.yaml`/`Chart.yaml`.
- Kratos, postgres-exporter, busybox, and CI-component versions live in the `dependencies`
  object at the top of `schema.ts`.
- Only `version`/`appVersion` in `Chart.yaml` are generated; the rest of `Chart.yaml`
  (metadata) is hand-maintained.

### Outputs and the sibling repo

| File             | Location                                                                                   | Notes                                          |
| ---------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| `values.yaml`    | chart root                                                                                 | fully generated                                |
| `Chart.yaml`     | chart root                                                                                 | only `version` + `appVersion` patched in place |
| `questions.yaml` | **sibling** `../rancher-partner-charts/packages/l3montree/devguard/overlay/questions.yaml` | fully generated                                |

The partner-charts repo is expected to sit next to this one. Override the path with
`PARTNER_QUESTIONS=/path/to/questions.yaml bun run generate`. The generator **skips** the
partner output if that directory is absent (e.g. in CI), so a missing sibling repo is not
an error.

**Generated files differ cosmetically from hand-written originals** — YAML quoting,
section-banner width, block-vs-flow sequences — but are _data-identical_. Don't chase those
diffs; only the parsed configuration matters.

## Repo layout

```
schema/            # ⭐ source of truth (TypeScript + bun) — edit here
templates/         # Helm templates (hand-written)
  _helpers.tpl     # devguard.image / devguard.labels / devguard.imagePullPolicy helpers
  devguard/        # API: deployment, ingress, secrets (encryption, pprof, intoto), hpa, service, servicemonitor
  devguard-web/    # web frontend: deployment, ingress, hpa, service
  kratos/          # Kratos deployment, config, secret, service, cleanup cronjob
  postgresql/      # statefulset, service, configmap, initdb, pvc, dashboards
  otel-collector/  # tracing sidecar config
  *.yaml           # db-secret, kratos-db-secret, networkpolicy, kyverno-policy
values.yaml        # GENERATED
Chart.yaml         # metadata hand-maintained; version/appVersion GENERATED
CHANGELOG.md       # hand-maintained; keep an [Unreleased] section
tests/kyverno/     # kyverno CLI policy tests
rancher/           # local Rancher test harness (compose, Caddy, e2e) + setup docs
.gitlab-ci.yml     # primary CI (validate → publish → release)
.github/workflows/ # helm-test, rancher-catalog-test, mirror-to-gitlab, helm-release
```

## Rancher constraints (why the chart looks the way it does)

The Rancher install form drives several deliberate limitations. Respect these — they were
intentional, not accidental:

- **Single ingress host.** `api.ingress.host` / `web.ingress.host` are scalars, not lists.
  Each ingress serves exactly one host at path `/` (pathType `Prefix`). The old
  `hosts[]` list shape now **fails the template with a migration hint** — the Rancher form
  can't address list entries like `hosts[0].host`.
- **Boolean TLS.** `*.ingress.tls` is a boolean (matches Rancher's mTLS toggle); the cert
  comes from `*.ingress.tlsSecretName` (defaults `devguard-{api,web}-tls`). The old list
  shape fails with a hint.
- Fields exposed in the install form carry `question` metadata in `schema.ts`; group
  order is controlled by `GROUP_ORDER`.

## Versioning

All DevGuard components (API, web, chart, CI) share the same **minor** version. Any
`vX.Y.*` of one is compatible with any `vX.Y.*` of another; patches release independently.
Bump `devguardVersion` in `schema.ts` and regenerate.

## Working conventions / gotchas

- After any change that touches configurable values, run `cd schema && bun run generate`
  and commit the regenerated files together with the `schema.ts` change.
- Verify template changes with `helm lint .` and `helm template dg . -f <test-values>`
  (render, don't just lint) — confirm the values you added actually reach the manifests.
- Keep an `[Unreleased]` section in `CHANGELOG.md`; document breaking value changes there
  with a migration hint (mirrors the `fail` messages in the templates).
- Secrets (`db-secret`, `kratos`, encryption key, pprof, intoto) are auto-generated via
  the Helm `lookup` function and preserved across upgrades. Each has a
  `useExisting*` / `generate` toggle to bring your own secret (needed where `lookup` is
  unavailable, e.g. ArgoCD).
- `additionalEnvs` (per component) injects extra env vars and is run through `tpl`, so
  values can reference other chart values.
