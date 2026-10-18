import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import type { LayerVerdict } from "./verdict.ts";

const reportScript = join(import.meta.dirname, "report.ts");

// One directory per CI job, each holding the results.json its sweep wrote.
function jobResults(jobs: Record<string, LayerVerdict[]>): string {
  const root = mkdtempSync(join(tmpdir(), "report-"));
  for (const [job, verdicts] of Object.entries(jobs)) {
    mkdirSync(join(root, job));
    writeFileSync(join(root, job, "results.json"), JSON.stringify(verdicts));
  }
  return root;
}

function report(args: string[]) {
  const dir = mkdtempSync(join(tmpdir(), "summary-"));
  const summaryFile = join(dir, "summary.md");
  const outputFile = join(dir, "output");
  writeFileSync(summaryFile, "");
  writeFileSync(outputFile, "");
  const run = spawnSync(process.execPath, [reportScript, ...args], {
    encoding: "utf8",
    env: { ...process.env, GITHUB_STEP_SUMMARY: summaryFile, GITHUB_OUTPUT: outputFile },
  });
  return {
    exitCode: run.status,
    summary: readFileSync(summaryFile, "utf8"),
    output: readFileSync(outputFile, "utf8"),
    stdout: run.stdout,
    stderr: run.stderr,
  };
}

test("a red layer turns the report red, and the summary names the layer and why", () => {
  const results = jobResults({
    "sweep-fast": [
      { id: "app", label: "app", verdict: "green" },
      { id: "endpoint", label: "endpoint", verdict: "red", reason: "error: 1 test failed" },
    ],
  });

  const { exitCode, summary, stderr } = report(["--expect", "app,endpoint", results]);

  assert.equal(exitCode, 1, stderr);
  assert.match(summary, /\| endpoint \| 🔴 red \| error: 1 test failed \|/);
  assert.match(summary, /\| app \| 🟢 green \|/);
});

test("an expected layer with no result is red, so a job that never ran or never finished cannot pass", () => {
  const results = jobResults({ "sweep-linux": [{ id: "app", label: "app", verdict: "green" }] });

  const { exitCode, summary, stderr } = report(["--expect", "app,e2e-ios", results]);

  assert.equal(exitCode, 1, stderr);
  assert.match(summary, /\| e2e \(ios\) \| 🔴 red \| no result \(its job did not run or did not finish\) \|/);
});

test("the per-layer table is also printed, so the job log names the red layer", () => {
  const results = jobResults({ "sweep-fast": [{ id: "endpoint", label: "endpoint", verdict: "red", reason: "exited with code 1" }] });

  const { stdout } = report(["--expect", "endpoint", results]);

  assert.match(stdout, /\| endpoint \| 🔴 red \| exited with code 1 \|/);
});

test("a run where some layer reached a real verdict says so, even when it is red, so a nightly can leave its marker", () => {
  const results = jobResults({ "sweep-linux": [{ id: "app", label: "app", verdict: "red", reason: "exited with code 1" }] });

  const { output } = report(["--expect", "app,e2e-ios", results]);

  assert.match(output, /^reached_verdict=true$/m);
});

test("rows filled in for missing jobs are not real verdicts", () => {
  const results = jobResults({});

  const { output } = report(["--expect", "app,e2e-ios", results]);

  assert.match(output, /^reached_verdict=false$/m);
});

test("when no job left any results the report still runs and shows every layer red", () => {
  const { exitCode, summary, output, stderr } = report(["--expect", "app", join(tmpdir(), "no-such-results-dir")]);

  assert.equal(exitCode, 1, stderr);
  assert.match(summary, /\| app \| 🔴 red \| no result/);
  assert.match(output, /^reached_verdict=false$/m);
});
