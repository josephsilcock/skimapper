import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const workflowsDir = join(import.meta.dirname, "..", "..", ".github", "workflows");

// The block under one trigger in a workflow's `on:` (two-space indented events), as text.
function trigger(workflow: string, event: string): string | undefined {
  const text = readFileSync(join(workflowsDir, workflow), "utf8");
  const on = text.match(/^on:\n((?:(?: .*)?\n)*)/m)?.[1] ?? "";
  return on.match(new RegExp(`^  ${event}:\\n((?:(?:    .*)?\\n)*)`, "m"))?.[1];
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
