import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { test } from "node:test";

import { UsageError } from "./cli.ts";
import { layersFromArgs, sweepLayers } from "./layers.ts";
import { commitUnderTest, runSweep, type Layer } from "./sweep.ts";

const resultsDir = () => mkdtempSync(join(tmpdir(), "sweep-"));

const stubLayer = (label: string, script: string): Layer => ({
  id: label,
  label,
  command: [process.execPath, "-e", script],
  cwd: tmpdir(),
  countTests: (output) => Number(/tests: (\d+)/.exec(output)?.[1] ?? 0),
});

test("a failing test in a layer turns the sweep red and names the layer and platform", async () => {
  const result = await runSweep({
    resultsDir: resultsDir(),
    layers: [
      stubLayer("app", "console.log('tests: 3')"),
      stubLayer("e2e (android)", "console.log('tests: 2'); process.exit(1)"),
    ],
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.culprits.map((culprit) => culprit.layer), ["e2e (android)"]);
});

test("a layer that runs no tests turns the sweep red and names it", async () => {
  const result = await runSweep({
    resultsDir: resultsDir(),
    layers: [stubLayer("endpoint", "console.log('tests: 0')")],
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.culprits, [{ layer: "endpoint", reason: "ran no tests" }]);
});

test("an unavailable device turns the sweep red and says which device", async () => {
  const missingDevice = "error: iOS simulator 'iPhone 99' (tools/dev.env IOS_SIMULATOR) is not available";
  const result = await runSweep({
    resultsDir: resultsDir(),
    layers: [stubLayer("e2e (ios)", `console.error(${JSON.stringify(missingDevice)}); process.exit(1)`)],
  });

  assert.equal(result.ok, false);
  assert.equal(result.culprits[0].layer, "e2e (ios)");
  assert.match(result.culprits[0].reason, /iPhone 99.*is not available/);
});

test("results from an earlier sweep are cleared before the layers run", async () => {
  const dir = resultsDir();
  mkdirSync(join(dir, "sweep"));
  writeFileSync(join(dir, "sweep", "e2e (ios).log"), "✅ Successful: 4");

  await runSweep({ resultsDir: dir, layers: [stubLayer("app", "console.log('tests: 1')")] });

  assert.equal(existsSync(join(dir, "sweep", "e2e (ios).log")), false);
});

test("each layer's output and a summary naming the culprits are written to the results dir", async () => {
  const dir = resultsDir();

  await runSweep({
    resultsDir: dir,
    layers: [
      stubLayer("app", "console.log('tests: 5')"),
      stubLayer("e2e (android)", "console.log('tests: 1'); process.exit(1)"),
    ],
  });

  assert.match(readFileSync(join(dir, "sweep", "app.log"), "utf8"), /tests: 5/);
  assert.match(readFileSync(join(dir, "sweep", "e2e (android).log"), "utf8"), /tests: 1/);
  assert.match(readFileSync(join(dir, "sweep", "summary.txt"), "utf8"), /RED[\s\S]*e2e \(android\): exited with code 1/);
});

test("each layer's verdict is written to results.json by id and label", async () => {
  const dir = resultsDir();

  await runSweep({
    resultsDir: dir,
    layers: [stubLayer("app", "console.log('tests: 5')"), stubLayer("endpoint", "console.log('tests: 0')")],
  });

  assert.deepEqual(JSON.parse(readFileSync(join(dir, "sweep", "results.json"), "utf8")), [
    { id: "app", label: "app", verdict: "green" },
    { id: "endpoint", label: "endpoint", verdict: "red", reason: "ran no tests" },
  ]);
});

test("each real layer counts the tests its runner reports", () => {
  const counts = Object.fromEntries(sweepLayers("/repo").map((layer) => [layer.label, layer.countTests]));

  assert.deepEqual(Object.keys(counts), ["app", "endpoint", "sweep self-test", "status-site", "e2e (ios)", "e2e (android)"]);
  assert.equal(counts["app"]("00:02 +13: All tests passed!\n"), 13);
  assert.equal(counts["app"]("00:02 +12 -1: Some tests failed.\n"), 13);
  assert.equal(counts["endpoint"]("      Tests  1 passed (1)\n"), 1);
  assert.equal(counts["sweep self-test"]("ℹ tests 6\nℹ pass 6\n"), 6);
  const patrol = "\u001b[32m✅ Successful: 2\u001b[0m\n❌ Failed: 0\n✅ Successful: 1\n❌ Failed: 1\n";
  assert.equal(counts["e2e (ios)"](patrol), 4);
  assert.equal(counts["e2e (android)"](patrol), 4);
});

test("the app layer fixes flutter test's reporter, so its count does not change under GitHub Actions", () => {
  const app = sweepLayers("/repo").find((layer) => layer.id === "app")!;

  assert.deepEqual(app.command, ["flutter", "test", "--reporter", "expanded"]);
});

test("the app layer's results come from Flutter's JSON report, by path below app/test, under the folder app", () => {
  const app = sweepLayers("/repo").find((layer) => layer.id === "app")!;
  const report = [
    { type: "suite", suite: { id: 0, path: "/repo/app/test/resorts/catalogue_test.dart" } },
    { type: "testStart", test: { id: 1, name: "lists resorts", suiteID: 0 } },
    { type: "testDone", testID: 1, result: "success", skipped: false, hidden: false },
  ].map((event) => JSON.stringify(event)).join("\n");

  assert.deepEqual(app.results?.reportArgs?.("/out/app.report"), ["--file-reporter", "json:/out/app.report"]);
  assert.deepEqual(app.results?.read({ output: "", report }), [
    { file: "/repo/app/test/resorts/catalogue_test.dart", name: "lists resorts", status: "passed" },
  ]);
  assert.deepEqual([app.results?.folder, app.results?.testRoot], ["app", "/repo/app/test"]);
});

test("each E2E layer's results come from Patrol's lines, by path below app/patrol_test, under its platform's folder", () => {
  const output = "✅ credits the map \u001b[90m(/catalogue_serving/attribution_test.dart)\u001b[0m \u001b[90m(4s)\u001b[0m\n";

  for (const platform of ["ios", "android"]) {
    const e2e = sweepLayers("/repo").find((layer) => layer.id === `e2e-${platform}`)!;
    assert.deepEqual(e2e.results?.read({ output, report: "" }), [
      { file: "/repo/app/patrol_test/catalogue_serving/attribution_test.dart", name: "credits the map", status: "passed" },
    ]);
    assert.deepEqual([e2e.results?.folder, e2e.results?.testRoot], [platform, "/repo/app/patrol_test"]);
  }
});

test("each layer's folders are positioned by the layer's place in the sweep", () => {
  const positions = sweepLayers("/repo").filter((layer) => layer.results).map((layer) => [layer.id, layer.results?.position]);

  assert.deepEqual(positions, [["app", 0], ["e2e-ios", 4], ["e2e-android", 5]]);
});

test("the layers are identified, in order, by the ids the --layers switch takes", () => {
  assert.deepEqual(
    sweepLayers("/repo").map((layer) => layer.id),
    ["app", "endpoint", "self-test", "status-site", "e2e-ios", "e2e-android"],
  );
});

test("the status-site layer runs the site's tests in status-site/ and counts what Node's runner reports", () => {
  const site = sweepLayers("/repo").find((layer) => layer.id === "status-site")!;

  assert.deepEqual([site.command, site.cwd], [["npm", "test"], "/repo/status-site"]);
  assert.equal(site.countTests("ℹ tests 8\nℹ pass 8\n"), 8);
});

test("--layers runs only the named layers, in sweep order", () => {
  const selected = layersFromArgs(sweepLayers("/repo"), ["--layers", "self-test,endpoint"], "--layers");

  assert.deepEqual(selected.map((layer) => layer.id), ["endpoint", "self-test"]);
});

test("with no --layers switch every layer runs, in the local sweep's order", () => {
  const selected = layersFromArgs(sweepLayers("/repo"), [], "--layers");

  assert.deepEqual(selected.map((layer) => layer.label), ["app", "endpoint", "sweep self-test", "status-site", "e2e (ios)", "e2e (android)"]);
});

test("--layers with an unknown id stops the sweep and names the id", () => {
  assert.throws(() => layersFromArgs(sweepLayers("/repo"), ["--layers", "app,e2e-windows"], "--layers"), /unknown layer 'e2e-windows'/);
});

test("--layers with an empty value or an empty item is a usage error naming the switch and the ids", () => {
  for (const value of ["", "app,", ","]) {
    assert.throws(
      () => layersFromArgs(sweepLayers("/repo"), ["--layers", value], "--layers"),
      (error) =>
        error instanceof UsageError &&
        error.message === "--layers needs a comma-separated list of layer ids (ids: app, endpoint, self-test, status-site, e2e-ios, e2e-android)",
      `value '${value}'`,
    );
  }
});

test("a layer's test results are written as JUnit under junit/, by layer id, stamped with the commit and when it ran", async () => {
  const dir = resultsDir();
  const layer: Layer = {
    ...stubLayer("app", "console.log('tests: 1'); console.log('passed: works')"),
    results: {
      folder: "app",
      testRoot: "/t",
      position: 0,
      read: ({ output }) => [...output.matchAll(/^passed: (.*)$/gm)].map(([, name]) => ({ file: "/t/a_test.dart", name, status: "passed" })),
    },
  };
  const before = new Date().toISOString();

  await runSweep({ resultsDir: dir, layers: [layer], commit: "c0ffee" });

  const junit = readFileSync(join(dir, "sweep", "junit", "app.xml"), "utf8");
  assert.match(junit, /<property name="commit" value="c0ffee"\/>/);
  const time = /<property name="time" value="([^"]+)"\/>/.exec(junit)?.[1] ?? "";
  assert.ok(time >= before && time <= new Date().toISOString(), `time ${time}`);
  assert.match(junit, /<testsuite name="app" tests="1"[^>]*>\n    <testcase classname="a_test.dart" name="works"\/>/);
});

test("a layer whose runner reports to a file is given one, and its results are read from that report", async () => {
  const dir = resultsDir();
  const writesReport = "const file = process.argv.at(-1); require('node:fs').writeFileSync(file, 'passed: from the report'); console.log('tests: 1')";
  const layer: Layer = {
    ...stubLayer("app", writesReport),
    results: {
      folder: "app",
      testRoot: "/t",
      position: 0,
      reportArgs: (reportFile) => ["--", reportFile],
      read: ({ report }) => [{ file: "/t/a_test.dart", name: report.replace("passed: ", ""), status: "passed" }],
    },
  };

  await runSweep({ resultsDir: dir, layers: [layer] });

  assert.match(readFileSync(join(dir, "sweep", "junit", "app.xml"), "utf8"), /name="from the report"/);
});

test("a layer that leaves a background process holding its output still finishes", { timeout: 5000 }, async () => {
  const leavesDaemon = `
    require("node:child_process").spawn("sleep", ["20"], { stdio: "inherit", detached: true }).unref();
    console.log("tests: 1");`;

  const result = await runSweep({ resultsDir: resultsDir(), layers: [stubLayer("app", leavesDaemon)] });

  assert.equal(result.ok, true);
});

test("the commit under test is GitHub's SHA under Actions, else the checkout's HEAD", () => {
  const repoDir = join(import.meta.dirname, "..", "..");
  const head = spawnSync("git", ["rev-parse", "HEAD"], { cwd: repoDir, encoding: "utf8" }).stdout.trim();

  assert.equal(commitUnderTest(repoDir, { GITHUB_SHA: "c0ffee" }), "c0ffee");
  assert.equal(commitUnderTest(repoDir, {}), head);
});
