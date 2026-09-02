import { resolve } from "node:path";
import { parse } from "yaml";

const apiOrg = "e1f24270-6e68-4571-9168-9c151c639c97";
const webOrg = "169319b7-8170-469f-9e31-f87b6054e507";

const artifacts: Record<
  string,
  { org: string; name: string; repo: string; upstreamVersion?: string }
> = {
  // kratos/postgresql OCI tags carry an upstream-version prefix (e.g.
  // "16.15-v1.13.3-amd64") - see upstream_version in devguard's
  // .gitlab-ci.yml and --upstream-version in
  // .github/workflows/devguard-scanner.yaml.
  kratos: {
    org: apiOrg,
    name: "kratos",
    repo: "ghcr.io/l3montree-dev/devguard/kratos",
    upstreamVersion: "v26.2.0",
  },
  api: {
    org: apiOrg,
    name: "devguard",
    repo: "ghcr.io/l3montree-dev/devguard",
  },
  web: {
    org: webOrg,
    name: "devguard-web",
    repo: "ghcr.io/l3montree-dev/devguard-web",
  },
  postgresql: {
    org: apiOrg,
    name: "postgresql",
    repo: "ghcr.io/l3montree-dev/devguard/postgresql",
    upstreamVersion: "16.15",
  },
};

async function readTagsFromRepo(repoRoot: string) {
  const chart = parse(await Bun.file(resolve(repoRoot, "Chart.yaml")).text());
  const values = parse(await Bun.file(resolve(repoRoot, "values.yaml")).text());

  const apiTag = chart.appVersion as string;
  const webTag = values.web.image.tag as string;

  return {
    kratos: apiTag,
    api: apiTag,
    web: webTag,
    postgresql: apiTag,
  };
}

export function buildSBOMUrls(tags: Record<keyof typeof artifacts, string>) {
  return Object.entries(artifacts).map(([key, { org, name, repo, upstreamVersion }]) => {
    const tag = tags[key as keyof typeof artifacts];
    const ociTag = upstreamVersion ? `${upstreamVersion}-${tag}` : tag;
    const purl = `pkg:oci/${name}?repository_url=${repo}&arch=amd64&tag=${ociTag}-amd64`;
    return {
      name: key,
      url: `https://api.main.devguard.org/api/v1/public/${org}/refs/${tag.replace(/\./g, "-")}/artifacts/${encodeURIComponent(purl)}/sbom.json/`,
    };
  });
}

export async function buildSBOMArtifact(repoRoot: string) {
  const tags = await readTagsFromRepo(repoRoot);
  return {
    artifactName: "pkg:oci/devguard-helm-chart",
    informationSources: buildSBOMUrls(tags).map(({ url }) => ({ url })),
  };
}

if (import.meta.main) {
  const repoRoot = resolve(import.meta.dir, "..");
  const outPath = resolve(repoRoot, ".github/sbom-artifact.json");
  await Bun.write(
    outPath,
    JSON.stringify(await buildSBOMArtifact(repoRoot)) + "\n",
  );
  console.log(`wrote ${outPath}`);
}
