import { dependencies } from "./versions";

const apiOrg = "e1f24270-6e68-4571-9168-9c151c639c97";
const webOrg = "169319b7-8170-469f-9e31-f87b6054e507";
const opencode = "registry.opencode.de/oci-community/images/l3montree/devguard";

const artifacts = {
  kratos: { org: apiOrg, name: "kratos", repo: `${opencode}/devguard/kratos` },
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
    repo: `${opencode}/devguard/postgresql`,
  },
};

export function buildSBOMUrls(deps: typeof dependencies) {
  return Object.entries(artifacts).map(([key, { org, name, repo }]) => {
    const tag = deps[key as keyof typeof artifacts].tag;
    const purl = `pkg:oci/${name}?repository_url=${repo}&arch=amd64&tag=${tag}-amd64`;
    return {
      name: key,
      url: `https://api.main.devguard.org/api/v1/public/${org}/refs/${tag.replace(/\./g, "-")}/artifacts/${encodeURIComponent(purl)}/sbom.json/`,
    };
  });
}
