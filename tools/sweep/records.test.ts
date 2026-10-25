import assert from "node:assert/strict";
import { test } from "node:test";

import { flutterRecords, patrolRecords } from "./records.ts";

// Lines of `flutter test --file-reporter json:<file>`, as captured from a real run (trimmed).
const flutterReport = [
  { protocolVersion: "0.1.1", runnerVersion: null, pid: 1, type: "start", time: 0 },
  { suite: { id: 0, platform: "vm", path: "/repo/app/test/text/fold_test.dart" }, type: "suite", time: 0 },
  { test: { id: 1, name: "loading /repo/app/test/text/fold_test.dart", suiteID: 0, groupIDs: [] }, type: "testStart", time: 0 },
  { suite: { id: 2, platform: "vm", path: "/repo/app/test/main_test.dart" }, type: "suite", time: 4 },
  { testID: 1, result: "success", skipped: false, hidden: true, type: "testDone", time: 4458 },
  { test: { id: 5, name: "folds away accents and capitals", suiteID: 0, groupIDs: [4] }, type: "testStart", time: 4459 },
  { testID: 5, result: "success", skipped: false, hidden: false, type: "testDone", time: 4472 },
  { test: { id: 7, name: "catalogue store saves exactly as served", suiteID: 2, groupIDs: [6] }, type: "testStart", time: 4830 },
  { testID: 7, result: "failure", skipped: false, hidden: false, type: "testDone", time: 5285 },
  { test: { id: 8, name: "logs its launch", suiteID: 2, groupIDs: [6] }, type: "testStart", time: 4830 },
  { testID: 8, result: "error", skipped: false, hidden: false, type: "testDone", time: 5285 },
  { test: { id: 9, name: "a corrupt saved copy counts as nothing", suiteID: 2, groupIDs: [6] }, type: "testStart", time: 4830 },
  { testID: 9, result: "success", skipped: true, hidden: false, type: "testDone", time: 5285 },
  { success: false, type: "done", time: 5290 },
].map((event) => JSON.stringify(event)).join("\n");

test("Flutter's JSON report gives one record per visible test, with its file and whether it passed, failed or was skipped", () => {
  assert.deepEqual(flutterRecords(flutterReport), [
    { file: "/repo/app/test/text/fold_test.dart", name: "folds away accents and capitals", status: "passed" },
    { file: "/repo/app/test/main_test.dart", name: "catalogue store saves exactly as served", status: "failed" },
    { file: "/repo/app/test/main_test.dart", name: "logs its launch", status: "failed" },
    { file: "/repo/app/test/main_test.dart", name: "a corrupt saved copy counts as nothing", status: "skipped" },
  ]);
});

test("a test's printed lines and reported errors are not results of their own", () => {
  const report = [
    { suite: { id: 0, platform: "vm", path: "/repo/app/test/main_test.dart" }, type: "suite", time: 0 },
    { test: { id: 7, name: "logs its launch", suiteID: 0, groupIDs: [] }, type: "testStart", time: 1 },
    { testID: 7, messageType: "print", message: "[app 2026-10-25T19:40:14.376Z] app launch", type: "print", time: 2 },
    { testID: 7, error: "Expected: true", stackTrace: "", isFailure: true, type: "error", time: 3 },
    { testID: 7, result: "failure", skipped: false, hidden: false, type: "testDone", time: 4 },
  ].map((event) => JSON.stringify(event)).join("\n");

  assert.deepEqual(flutterRecords(report), [{ file: "/repo/app/test/main_test.dart", name: "logs its launch", status: "failed" }]);
});

// Lines of an E2E layer's log, as captured from a real sweep (Patrol 4.8, trimmed): gray ANSI around the file
// and duration, step lines indented, and the app's own lines behind "flutter: ".
const patrolOutput = [
  "flutter: PatrolAppService: requested execution of test \"catalogue_serving.attribution_test credits the map\"",
  "\u001b[A\u001b[K        ✅   1. \u001b[36mwaitUntilVisible\u001b[0m widgets with text \"© OpenStreetMap\".",
  "✅ credits the map \u001b[90m(/catalogue_serving/attribution_test.dart)\u001b[0m \u001b[90m(4s)\u001b[0m",
  "flutter: ✅ spoofed by the app \u001b[90m(/catalogue_serving/attribution_test.dart)\u001b[0m \u001b[90m(4s)\u001b[0m",
  "✅ renders the tile (Wi-Fi and cellular are cut on Android only) \u001b[90m(/catalogue_serving/offline_map_test.dart)\u001b[0m \u001b[90m(3s)\u001b[0m",
  "❌ relaunch 2 of 2: still shows the saved list \u001b[90m(/endpoint_scripted/offline_relaunch_test.dart)\u001b[0m \u001b[90m(5s)\u001b[0m",
  "Expected: exactly one matching candidate",
  "⏩ endpoint_scripted.pull_to_refresh_test pulling the list down shows a new area",
  "📝 Total: 4",
  "✅ Successful: 2",
  "❌ Failed: 1",
  "⏩ Skipped: 1",
].join("\n") + "\n";

test("Patrol's result lines give one record per test, under the Patrol test root; a line not at the start is not a result", () => {
  assert.deepEqual(patrolRecords(patrolOutput, "/repo/app/patrol_test"), [
    { file: "/repo/app/patrol_test/catalogue_serving/attribution_test.dart", name: "credits the map", status: "passed" },
    {
      file: "/repo/app/patrol_test/catalogue_serving/offline_map_test.dart",
      name: "renders the tile (Wi-Fi and cellular are cut on Android only)",
      status: "passed",
    },
    {
      file: "/repo/app/patrol_test/endpoint_scripted/offline_relaunch_test.dart",
      name: "relaunch 2 of 2: still shows the saved list",
      status: "failed",
    },
    {
      file: "/repo/app/patrol_test/endpoint_scripted/pull_to_refresh_test.dart",
      name: "pulling the list down shows a new area",
      status: "skipped",
    },
  ]);
});
