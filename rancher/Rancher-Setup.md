# Rancher (local dev)

## On MacOS: run inside a Linux VM

OrbStack / Docker Desktop for macOS don't support nested containers (DinD)
properly. The `rancher/rancher` all-in-one image runs an embedded k3s with its
**own** containerd inside the container. On OrbStack that inner containerd cannot
mount `/proc` into pod sandboxes (`read-only file system`), so **no pod ever
starts** — CoreDNS, the fleet helm-operation pods, and the cluster agent all
fail, and Rancher hangs during bootstrap (`RDPClient: Dialer is not built yet…`).

**The fix is to run Rancher inside a real Linux VM, which has a genuine kernel and
supports nested containers. This tutorial assumes that you are using OrbStack on MacOS.**

### 1. Create the VM

```bash
orb create ubuntu rancher-vm
```

### 2. Install Docker in the VM

```bash
orb -m rancher-vm bash -c '
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker $(whoami)
'
```

### 3. Bring Rancher up

The e2e scripts already automate bring-up correctly. For interactive dev, run just phases 01–04:

```bash
cd ~/projects/devguard-helm-chart
orb -m rancher-vm bash ./rancher/e2e/01-up.sh              # compose up on native fs
orb -m rancher-vm bash ./rancher/e2e/02-wait-rancher.sh    # wait for /healthz
orb -m rancher-vm bash ./rancher/e2e/03-bootstrap.sh       # admin password + kubeconfig
orb -m rancher-vm bash ./rancher/e2e/04-cluster-prereqs.sh # local-path + ingress-nginx
```

Open `https://rancher-vm.orb.local/` in the browser (accept the self-signed
cert) and log in as `admin` / `devguard-ci-admin-pw` (overridable via
`RANCHER_ADMIN_PASSWORD`; see `rancher/e2e/env.sh`).

### Resetting

```bash
orb -m rancher-vm bash ./rancher/e2e/99-down.sh   # tear down container + state
orb delete rancher-vm                             # delete the whole VM
```

## Setup DevGuard

- Setup custom DNS
  - Add the following entries to the `/etc/hosts` file
  - ```bash
      # sudo nano /etc/hosts
      127.0.0.1 api.devguard.rancher-local.de
      127.0.0.1 devguard.rancher-local.de
      127.0.0.1 rancher-local.de
    ```
- Setup Reverse-Proxy
  - `brew install caddy`
  - `caddy run --config Caddyfile`
  - > Caddy runs on the Mac and fronts the `kubectl port-forward`s below,
    > terminating TLS with the real `*.rancher-local.de` hostnames (the frontend
    > and ORY need proper hostnames). This is only used for manually testing the setup.
    > The e2e tests work differently (using ingress-nginx - see `04-cluster-prereqs.sh`)
- Add Test-Repo
  - Login to Rancher -> Apps -> Repositories -> Create: https://rancher-vm.orb.local/dashboard/c/local/apps/catalog.cattle.io.clusterrepo/create
  - Select `Git Repository` and enter URL: https://github.com/l3montree-dev/rancher-partner-charts.git (Branch: main-source)
  - Optional: Disable the official "Partners" Repo - otherwise all apps will appear twice
- Install DevGuard
  - Apps → DevGuard -> Install
  - Create new Namespace `devguard`
  - API Ingress Host: `api.devguard.rancher-local.de`
  - Web Ingress Host: `devguard.rancher-local.de`
  - Storage: `local-path`
- Check under "Deployments" if it's running
  - https://rancher-local.de/dashboard/c/local/explorer/apps.deployment
- Setup Port Forwarding
  - In Rancher select the Cluster and download the Kubeconfig. Copy it to `~/Downloads/kubernetes/rancher-local/config.yaml` and run the following commands to setup the port forwarding
  - ```bash
      export KUBECONFIG=~/Downloads/kubernetes/rancher-local/config.yaml
      # kubectl config get-clusters
      kubectl config unset clusters.local.certificate-authority-data
      kubectl config set-cluster rancher --insecure-skip-tls-verify=true
      kubectl port-forward -n devguard svc/devguard-api-service 8080:8080
      kubectl port-forward -n devguard svc/devguard-web-service 3000:3000
    ```
  - ...
- Uninstall DevGuard
  - Apps -> Installed Apps -> Three dot menu -> Uninstall

In theory you can also use Ranchers proxy URLs but DevGuard doesn't support Prefix Paths properly so it's not possible at this point. E.g. https://rancher-vm.orb.local/api/v1/namespaces/devguard/services/http:devguard-api-service:8080/proxy/api/v1/info (API seems to work but Frontend and especially ORY has issues with it.)
