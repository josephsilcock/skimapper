import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

import { layersFromArgs, sweepLayers } from "./layers.ts";

const repoDir = join(import.meta.dirname, "..", "..");
const githubDir = join(repoDir, ".github");
const workflowsDir = join(githubDir, "workflows");

// Every workflow and composite action, as text.
function ciFiles(): { path: string; text: string }[] {
  return readdirSync(githubDir, { recursive: true, encoding: "utf8" })
    .filter((path) => /\.ya?ml$/.test(path))
    .map((path) => ({ path, text: readFileSync(join(githubDir, path), "utf8") }));
}

// The block under one trigger in a workflow's `on:` (two-space indented events), as text.
function trigger(workflow: string, event: string): string | undefined {
  const text = readFileSync(join(workflowsDir, workflow), "utf8");
  const on = text.match(/^on:\n((?:(?: .*)?\n)*)/m)?.[1] ?? "";
  return on.match(new RegExp(`^  ${event}:\\n((?:(?:    .*)?\\n)*)`, "m"))?.[1];
}

// The arguments of each tools/full-sweep call in a workflow: a `run:` value, or a line of a `run: |` block,
// whose first word is tools/full-sweep. A plain word split, so a quoted or $VAR value reads as itself; words
// after an inline ` #` are the shell's comment. A list item or block-scalar line starting with the word also
// reads as a call: that fails visibly, which is accepted.
function fullSweepCalls(workflow: string): string[][] {
  const text = readFileSync(join(workflowsDir, workflow), "utf8");
  return [...text.matchAll(/^\s*(?:-\s+)?(?:run:\s+)?tools\/full-sweep(?=\s|$)(.*)$/gm)]
    .map((call) => call[1].replace(/\s#.*/, "").split(/\s+/).filter(Boolean));
}

function docsOnlyPaths(block: string | undefined): string[] {
  const list = block?.match(/^    paths-ignore:\n((?:      - .*\n)*)/m)?.[1] ?? "";
  return list.split("\n").filter(Boolean).map((line) => line.replace(/^\s*- /, ""));
}

test("fast checks run on every PR to main, docs-only included, and on pushes to every other branch", () => {
  const pullRequest = trigger("push.yml", "pull_request");
  const push = trigger("push.yml", "push");

  assert.match(pullRequest ?? "", /^    branches: \[main\]$/m);
  assert.deepEqual(docsOnlyPaths(pullRequest), [], "a required check must report on docs-only PRs");
  assert.match(push ?? "", /^    branches-ignore: \[main\]$/m);
});

test("branch pushes and main pushes skip the same docs-only paths", () => {
  const fast = docsOnlyPaths(trigger("push.yml", "push"));

  assert.notDeepEqual(fast, []);
  assert.deepEqual(docsOnlyPaths(trigger("sweep.yml", "push")), fast);
});

test("no workflow or action restates a test command: they run tools/full-sweep instead", () => {
  const testCommand = /\bflutter test\b|\bnpm (?:run )?test\b|\bvitest\b|\bpatrol (?:test|build)\b|\bnode --test\b/;
  const offenders = ciFiles().filter(({ text }) => testCommand.test(text)).map(({ path }) => path);

  assert.deepEqual(offenders, []);
});

test("the full sweep's jobs between them run every layer exactly once", () => {
  const layers = sweepLayers(repoDir);
  const runs = fullSweepCalls("sweep.yml").flatMap((args) => layersFromArgs(layers, args, "--layers"));
  const timesRun = (id: string) => runs.filter((layer) => layer.id === id).length;

  const notOnce = layers
    .map(({ id }) => ({ id, times: timesRun(id) }))
    .filter(({ times }) => times !== 1)
    .map(({ id, times }) => `${id}: ${times === 0 ? "missing" : `runs ${times} times`}`);

  assert.deepEqual(notOnce, []);
});

// Each job's steps under `jobs:`, as text, by job id.
function jobs(workflow: string): Record<string, string> {
  const text = readFileSync(join(workflowsDir, workflow), "utf8");
  const body = text.slice(text.search(/^jobs:\n/m));
  return Object.fromEntries([...body.matchAll(/^  ([\w-]+):\n((?:(?:    .*)?\n)*)/gm)].map(([, id, block]) => [id, block]));
}

test("each job that runs the sweep uploads its JUnit as junit-<job id>, kept 90 days and replaced on a re-run", () => {
  const sweepJobs = Object.entries(jobs("sweep.yml")).filter(([, steps]) => /tools\/full-sweep/.test(steps));
  const upload = (id: string) =>
    ["        if: ${{ !cancelled() }}", "        with:", `          name: junit-${id}`, "          path: test-results/sweep/junit/",
      "          retention-days: 90", "          overwrite: true"].join("\n");

  assert.deepEqual(sweepJobs.map(([id]) => id), ["linux", "android", "ios"]);
  for (const [id, steps] of sweepJobs) assert.ok(steps.includes(upload(id)), `job ${id} uploads no junit-${id}`);
});

// The layer ids a job's tools/full-sweep calls run, with a workflow-level env value such as $FAST_LAYERS
// read as itself.
function layersRunBy(workflow: string, steps: string): string[] {
  const env = Object.fromEntries(
    [...readFileSync(join(workflowsDir, workflow), "utf8").matchAll(/^  ([A-Z_]+): (.*)$/gm)].map(([, name, value]) => [name, value]),
  );
  return [...steps.matchAll(/tools\/full-sweep (.*)$/gm)]
    .map(([, args]) => args.replace(/"?\$([A-Z_]+)"?/g, (_, name: string) => env[name] ?? "").split(/\s+/))
    .flatMap((args) => layersFromArgs(sweepLayers(repoDir), args, "--layers").map((layer) => layer.id));
}

test("every job that runs the status-site layer installs the site's packages first, and no other job does", () => {
  const install = "      - name: Install status-site dependencies\n        run: npm ci\n        working-directory: status-site\n";
  const installsFirst = (steps: string) => steps.includes(install) && steps.indexOf(install) < steps.indexOf("tools/full-sweep");
  const offenders = ["push.yml", "sweep.yml"].flatMap((workflow) =>
    Object.entries(jobs(workflow))
      .filter(([, steps]) => layersRunBy(workflow, steps).includes("status-site") !== installsFirst(steps))
      .map(([id]) => `${workflow} ${id}`),
  );

  assert.deepEqual(offenders, []);
});
