import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const gateScript = join(import.meta.dirname, "gate.ts");

// Runs gate.ts on the two GitHub API answers it is fed in CI: scheduled runs, and nightly-verdict artifacts.
function gate(sha: string, runId: number, workflowRuns: object[], artifacts: object[]) {
  const dir = mkdtempSync(join(tmpdir(), "gate-"));
  const files = { runs: join(dir, "runs.json"), markers: join(dir, "markers.json"), output: join(dir, "output"), summary: join(dir, "summary.md") };
  writeFileSync(files.runs, JSON.stringify({ workflow_runs: workflowRuns }));
  writeFileSync(files.markers, JSON.stringify({ artifacts }));
  writeFileSync(files.output, "");
  writeFileSync(files.summary, "");
  const run = spawnSync(process.execPath, [gateScript, "--sha", sha, "--run", String(runId), files.runs, files.markers], {
    encoding: "utf8",
    env: { ...process.env, GITHUB_OUTPUT: files.output, GITHUB_STEP_SUMMARY: files.summary },
  });
  return { exitCode: run.status, stdout: run.stdout, stderr: run.stderr, output: readFileSync(files.output, "utf8"), summary: readFileSync(files.summary, "utf8") };
}

test("a head an earlier nightly swept is reported as swept, naming that run", () => {
  const result = gate("c0ffee", 9, [{ id: 7, head_sha: "c0ffee", html_url: "https://runs/7" }], [{ expired: false, workflow_run: { id: 7 } }]);

  assert.equal(result.exitCode, 0, result.stderr);
  assert.match(result.output, /^swept=true$/m);
  assert.match(result.summary, /already swept by https:\/\/runs\/7/);
});

test("an unswept head is reported with how many earlier scheduled runs were checked, so a broken marker path shows", () => {
  const result = gate("c0ffee", 9, [{ id: 7, head_sha: "c0ffee", html_url: "https://runs/7" }], []);

  assert.match(result.output, /^swept=false$/m);
  assert.match(result.summary, /no nightly-verdict marker among 1 earlier scheduled runs on c0ffee/);
});
