import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { test } from "node:test";

const toolsDir = join(import.meta.dirname, "..");

const sourceCommon = (script: string, env: NodeJS.ProcessEnv = {}) =>
  spawnSync("bash", ["-c", `source "${toolsDir}/lib/common.sh" && ${script}`], {
    encoding: "utf8",
    env: { PATH: process.env.PATH, HOME: process.env.HOME, ...env },
  });

test("the shared tool setup needs no JDK, so the sweep's non-Android layers start without one", () => {
  const run = sourceCommon('echo "JAVA_HOME=${JAVA_HOME-unset}"');

  assert.equal(run.stdout.trim(), "JAVA_HOME=unset", run.stderr);
});
