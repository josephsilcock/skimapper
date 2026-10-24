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
