/**
 * Single source of truth for the DevGuard Helm chart's versions and images.
 *
 * All version numbers live here so there is one place to look when cutting a
 * release. The api, web, chart and ci-components versions are released
 * independently (see devguard-maint's `release helm-chart` and
 * `release ci-components` commands), so each is its own required env var with
 * no default. `dependencies` maps those versions onto the concrete images the
 * chart ships; schema.ts imports it to build values.yaml.
 */

/** Read a required env var or throw — these version knobs have no default. */
function requiredEnv(name: string): string {
  const v = process.env[name];
  if (!v) {
    throw new Error(
      `${name} is required (e.g. ${name}=1.9.0). Set API_VERSION, WEB_VERSION, CHART_VERSION and CI_COMPONENTS_VERSION before running generate.`,
    );
  }
  return v;
}

// Independent version knobs (used by devguard-maint's `release helm-chart`
// command, which can release the api, web, chart, and ci-components at
// different versions/cadences). No defaults — all must be set explicitly.
export const apiVersion = requiredEnv("API_VERSION");
export const webVersion = requiredEnv("WEB_VERSION");
// The Helm chart's own version/appVersion.
export const chartVersion = requiredEnv("CHART_VERSION");
// devguard-ci-components is tagged and released independently (see
// devguard-maint's `release ci-components` command) — its version does not
// track the chart's own version.
export const ciComponentsVersion = requiredEnv("CI_COMPONENTS_VERSION");

export const dependencies = {
  // kratos is now built and published as our own image (see
  // nix/kratos.nix in the devguard repo), tagged and released alongside
  // devguard/postgresql, so it tracks apiVersion like postgresql does below.
  kratos: {
    repo: "ghcr.io/l3montree-dev/devguard/kratos",
    tag: `v${apiVersion}`,
  },
  api: {
    repo: "ghcr.io/l3montree-dev/devguard",
    tag: `v${apiVersion}`,
  },
  web: {
    repo: "ghcr.io/l3montree-dev/devguard-web",
    tag: `v${webVersion}`,
  },
  postgresql: {
    repo: "ghcr.io/l3montree-dev/devguard/postgresql",
    tag: `v${apiVersion}`,
  },
  postgresVolumePermissionImage: {
    repo: "busybox",
    tag: "1.37.0@sha256:1487d0af5f52b4ba31c7e465126ee2123fe3f2305d638e7827681e7cf6c83d5e",
  },
  postgresExporter: {
    repo: "prometheuscommunity/postgres-exporter",
    tag: "v0.19.1",
  },
  ciComponents: {
    version: `v${ciComponentsVersion}`,
  },
};
