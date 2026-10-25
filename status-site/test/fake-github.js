import { strToU8, zipSync } from "fflate";

export const repo = "o/r";

// A fetch that answers the GitHub REST calls the site makes, for the given runs. Each run's artifacts map
// an artifact name to its files' text.
export function fakeGitHub({ runs = [], token = "t0ken" } = {}) {
  const artifactFiles = new Map();
  const routes = new Map();
  for (const run of runs) {
    routes.set(`/repos/${repo}/actions/runs/${run.id}`, {
      id: run.id,
      run_number: run.number,
      html_url: `https://github.com/${repo}/actions/runs/${run.id}`,
      head_branch: run.branch ?? "main",
      head_sha: run.sha ?? "c0ffee",
    });
    const artifacts = Object.entries(run.artifacts ?? {}).map(([name, files], index) => {
      const id = run.id * 100 + index;
      artifactFiles.set(id, files);
      return { id, name, expired: false };
    });
    routes.set(`/repos/${repo}/actions/runs/${run.id}/artifacts?per_page=100`, { total_count: artifacts.length, artifacts });
  }
  return async (url, init = {}) => {
    const { pathname, search } = new URL(url);
    if (init.headers?.authorization !== `Bearer ${token}`) return Response.json({ message: "Bad credentials" }, { status: 401 });
    const zip = /^\/repos\/[^/]+\/[^/]+\/actions\/artifacts\/(\d+)\/zip$/.exec(pathname);
    if (zip) return new Response(zipOf(artifactFiles.get(Number(zip[1]))));
    const body = routes.get(pathname + search);
    return body ? Response.json(body) : Response.json({ message: "Not Found" }, { status: 404 });
  };
}

const zipOf = (files) => zipSync(Object.fromEntries(Object.entries(files).map(([name, text]) => [name, strToU8(text)])));
