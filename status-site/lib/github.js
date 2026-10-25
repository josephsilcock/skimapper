import { strFromU8, unzipSync } from "fflate";

// The GitHub REST calls the site makes, through the given fetch; read-only, with a token for this repo.
export function gitHub({ fetch, token, repo }) {
  const call = async (path) => {
    const response = await fetch(`https://api.github.com/repos/${repo}${path}`, {
      headers: { authorization: `Bearer ${token}`, accept: "application/vnd.github+json", "x-github-api-version": "2022-11-28" },
    });
    if (!response.ok) throw new Error(`GitHub answered ${response.status} to ${path}`);
    return response;
  };
  const json = async (path) => (await call(path)).json();
  return {
    run: (id) => json(`/actions/runs/${id}`),
    artifacts: async (runId) => (await json(`/actions/runs/${runId}/artifacts?per_page=100`)).artifacts,
    files: async (artifactId) => textFiles(await (await call(`/actions/artifacts/${artifactId}/zip`)).arrayBuffer()),
  };
}

// An artifact's zip, as each file's text by name.
function textFiles(zip) {
  const files = unzipSync(new Uint8Array(zip));
  return Object.fromEntries(Object.entries(files).map(([name, bytes]) => [name, strFromU8(bytes)]));
}
