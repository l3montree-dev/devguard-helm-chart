# Rancher catalog e2e test

End-to-end test of the DevGuard chart through a real Rancher: starts
`rancher/rancher` in Docker (see [../compose.yml](../compose.yml)), registers
the [partner-charts repo](https://github.com/l3montree-dev/rancher-partner-charts)
as a `ClusterRepo`, installs the chart via **Rancher's catalog API** (the same
code path the UI uses, spawning a helm-operation pod) and verifies that all
pods become healthy and the `/health` endpoints return 200 — both through the
chart's Ingress resources and directly against the services.

Everything is CLI/API driven, no Rancher UI involved. The GitHub workflow
([rancher-catalog-test.yaml](../../.github/workflows/rancher-catalog-test.yaml),
manual `workflow_dispatch`) is a thin wrapper around these scripts.

## Phases

| Script                  | What it does                                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `01-up.sh`              | copy compose.yml to `$RANCHER_STATE_DIR` (native fs) and `docker compose up -d` with `CATTLE_BOOTSTRAP_PASSWORD` pre-seeded          |
| `02-wait-rancher.sh`    | wait for `/healthz`                                                                                                                  |
| `03-bootstrap.sh`       | login, set admin password + `server-url`, generate kubeconfig for the `local` cluster, wait for cluster + rancher-webhook            |
| `04-cluster-prereqs.sh` | install local-path-provisioner + ingress-nginx (the embedded k3s disables traefik/servicelb/local-storage)                           |
| `05-clusterrepo.sh`     | create the `ClusterRepo`, wait for condition `Downloaded`, resolve the chart version from the index                                  |
| `06-install.sh`         | pre-create namespace + dummy secrets, `POST ?action=install`, follow the helm-operation pod, wait for the App to be `deployed`       |
| `07-smoke.sh`           | rollout status for all workloads, curl `/api/v1/health` (API) and `/api/health` (web) via ingress (Host header) and via the services |
| `08-uninstall.sh`       | uninstall through the catalog API (skip with `SKIP_UNINSTALL=1`)                                                                     |
| `90-diagnostics.sh`     | dump logs/events/pods on failure (run automatically by `run-all.sh`)                                                                 |
| `99-down.sh`            | tear down container + state                                                                                                          |

Configuration lives in `env.sh`; every variable can be overridden via the
environment, e.g. `CHART_VERSION`, `CHART_REPO_BRANCH`, `RANCHER_URL`.

## Running locally

The scripts are the same ones CI runs — but they need a real Linux kernel for
the nested containers inside `rancher/rancher` (see
[../Rancher-Setup.md](../Rancher-Setup.md)). On macOS run them inside an
OrbStack VM:

```bash
orb create ubuntu rancher-vm

# TODO! install docker in the VM (see Rancher-Setup.md)

cd ~/projects/devguard-helm-chart # navigate to the project/repo root

# run the full suite inside the VM (repo is reachable via the /Users mount;
# Rancher's data is placed on the VM's native fs automatically)
orb -m rancher-vm bash ./rancher/e2e/run-all.sh

# keep the app running for inspection instead of uninstalling:
orb -m rancher-vm env SKIP_UNINSTALL=1 bash ./rancher/e2e/run-all.sh

# tear down
orb -m rancher-vm bash ./rancher/e2e/99-down.sh
```

Alternatively run only `01-up.sh` in the VM and everything else from macOS
with `RANCHER_URL=https://<vm-ip>:8443` (find the IP with `orb list`).

`jq`, `curl`, `kubectl` and docker compose v2 must be available wherever the
scripts run.

> **Why not `act`?** Running the GitHub workflow locally with
> [nektos/act](https://github.com/nektos/act) does not work on macOS: the
> `rancher/rancher` container needs proper nested-container support, which
> Docker Desktop/OrbStack's Linux VM does not provide to privileged
> containers-in-containers (the same reason Rancher-Setup.md uses a VM).
> Since the workflow is only a thin wrapper, running `run-all.sh` in the VM
> tests exactly what CI executes.
