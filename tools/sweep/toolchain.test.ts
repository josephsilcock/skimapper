import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const toolsDir = join(import.meta.dirname, "..");

const sourceCommon = (script: string, env: NodeJS.ProcessEnv = {}) =>
  spawnSync("bash", ["-c", `source "${toolsDir}/lib/common.sh" && ${script}`], {
    encoding: "utf8",
    env: { PATH: process.env.PATH, HOME: process.env.HOME, ...env },
  });

function executable(path: string, script: string): void {
  writeFileSync(path, `#!/usr/bin/env bash\n${script}\n`);
  chmodSync(path, 0o755);
}

// A Linux host (as `uname` reports it) whose JAVA_HOME holds a JDK of the given version.
function linuxHostWithJdk(version: string): NodeJS.ProcessEnv {
  const root = mkdtempSync(join(tmpdir(), "linux-host-"));
  mkdirSync(join(root, "bin"));
  executable(join(root, "bin", "uname"), 'echo Linux');
  mkdirSync(join(root, "jdk", "bin"), { recursive: true });
  executable(join(root, "jdk", "bin", "java"), `echo 'openjdk version "${version}" 2026-01-20' >&2`);
  return { PATH: `${join(root, "bin")}:${process.env.PATH}`, JAVA_HOME: join(root, "jdk") };
}

test("the shared tool setup needs no JDK, so the sweep's non-Android layers start without one", () => {
  const run = sourceCommon('echo "JAVA_HOME=${JAVA_HOME-unset}"');

  assert.equal(run.stdout.trim(), "JAVA_HOME=unset", run.stderr);
});

test("off macOS, an Android build stops when JAVA_HOME is not the dev config's JDK, naming both", () => {
  const run = sourceCommon("use_android_jdk", { ...linuxHostWithJdk("17.0.12"), ANDROID_JDK_VERSION: "25" });

  assert.equal(run.status, 1);
  assert.match(run.stderr, /^error: JAVA_HOME .* is JDK 17; tools\/dev.env ANDROID_JDK_VERSION is 25/m);
});

test("off macOS, an Android build with no JAVA_HOME stops and says so", () => {
  const { PATH } = linuxHostWithJdk("25.0.1");
  const run = sourceCommon("use_android_jdk", { PATH, ANDROID_JDK_VERSION: "25" });

  assert.equal(run.status, 1);
  assert.match(run.stderr, /^error: JAVA_HOME is not set; .*JDK 25/m);
});

test("off macOS, an Android build continues when JAVA_HOME is the dev config's JDK in its GA form", () => {
  const run = sourceCommon("use_android_jdk && echo continued", { ...linuxHostWithJdk("25"), ANDROID_JDK_VERSION: "25" });

  assert.equal(run.stderr, "");
  assert.equal(run.stdout, "continued\n");
  assert.equal(run.status, 0);
});

test("off macOS, an Android build continues when JAVA_HOME is the dev config's JDK in its update form", () => {
  const run = sourceCommon("use_android_jdk && echo continued", { ...linuxHostWithJdk("25.0.1"), ANDROID_JDK_VERSION: "25" });

  assert.equal(run.stderr, "");
  assert.equal(run.stdout, "continued\n");
  assert.equal(run.status, 0);
});
