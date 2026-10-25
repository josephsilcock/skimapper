import assert from "node:assert/strict";
import { test } from "node:test";

import { gitHub } from "../lib/github.js";
import { readRun } from "../lib/runs.js";
import { fakeGitHub, repo } from "./fake-github.js";

const junit = (position, folder, testName) => `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <properties>
    <property name="commit" value="c0ffee"/>
    <property name="time" value="2026-10-24T14:52:07.000Z"/>
    <property name="position" value="${position}"/>
  </properties>
  <testsuite name="${folder}" tests="1" failures="0" skipped="0">
    <testcase classname="a_test.dart" name="${testName}"/>
  </testsuite>
</testsuites>
`;

test("a run is read with the JUnit reports in its junit-* artifacts, and nothing from its other artifacts", async () => {
  const fetch = fakeGitHub({
    runs: [
      {
        id: 7,
        number: 212,
        artifacts: {
          "junit-linux": { "app.xml": junit(0, "app", "logs its launch") },
          "junit-ios": { "e2e-ios.xml": junit(3, "ios / catalogue_serving", "credits the map") },
          "sweep-linux": { "results.json": "[]" },
        },
      },
    ],
  });

  const { run, reports } = await readRun(gitHub({ fetch, token: "t0ken", repo }), 7);

  assert.deepEqual(run, { id: 7, number: 212, url: "https://github.com/o/r/actions/runs/7" });
  assert.deepEqual(reports.map((report) => report.folders[0].tests[0].name).sort(), ["credits the map", "logs its launch"]);
});
