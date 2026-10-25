import assert from "node:assert/strict";
import { test } from "node:test";

import { linesOfRun } from "../lib/lines.js";

const report = (position, time, folders) => ({ commit: "c0ffee", time, position, folders });
const passed = (name, file = "a_test.dart") => ({ name, file, status: "passed" });
const failed = (name, file = "a_test.dart") => ({ name, file, status: "failed" });

test("a run's reports give its folders in layer order then path, each test a line, and the commit and latest time", () => {
  const reports = [
    report(4, "2026-10-24T15:10:00.000Z", [{ name: "android / catalogue_serving", tests: [failed("credits the map")] }]),
    report(0, "2026-10-24T14:52:00.000Z", [
      { name: "app / resorts", tests: [passed("lists resorts")] },
      { name: "app", tests: [passed("logs its launch")] },
    ]),
  ];

  assert.deepEqual(linesOfRun(reports), {
    commit: "c0ffee",
    time: "2026-10-24T15:10:00.000Z",
    folders: [
      { name: "app", lines: [{ name: "logs its launch", status: "passed" }] },
      { name: "app / resorts", lines: [{ name: "lists resorts", status: "passed" }] },
      { name: "android / catalogue_serving", lines: [{ name: "credits the map", status: "failed" }] },
    ],
  });
});
