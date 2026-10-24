import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const toolsDir = join(import.meta.dirname, "..");

// tools/full-sweep run from a temp copy of tools/, so whatever it selects runs and writes inside the copy.
function fullSweepCopy(args: string[]) {
  const repoDir = mkdtempSync(join(tmpdir(), "full-sweep-"));
  cpSync(toolsDir, join(repoDir, "tools"), { recursive: true });
  const { GITHUB_STEP_SUMMARY: _, ...env } = process.env;
  const run = spawnSync(join(repoDir, "tools", "full-sweep"), args, { encoding: "utf8", env });
  return { exitCode: run.status, stderr: run.stderr, ranAnything: existsSync(join(repoDir, "test-results")) };
}

test("tools/full-sweep with --layers and no value prints one error line naming the switch and the ids, and runs nothing", () => {
  const { exitCode, stderr, ranAnything } = fullSweepCopy(["--layers"]);

  assert.equal(stderr, "error: --layers needs a comma-separated list of layer ids (ids: app, endpoint, self-test, e2e-ios, e2e-android)\n");
  assert.equal(exitCode, 1);
  assert.equal(ranAnything, false);
});
