import { gitHub } from "./github.js";
import { linesOfRun } from "./lines.js";
import { readRun } from "./runs.js";
import { viewOf } from "./view.js";

// GET /api/view[?run=<id>]: the view JSON the page renders. env: { fetch, token, repo, deployment }.
export async function serveView(request, env) {
  const runId = new URL(request.url).searchParams.get("run");
  const { run, reports } = await readRun(gitHub(env), runId);
  const view = { kind: "run", ...viewOf(linesOfRun(reports), { ...run, published: false }) };
  return Response.json(view, { headers: { "cache-control": "public, s-maxage=300" } });
}
