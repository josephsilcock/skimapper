import assert from "node:assert/strict";
import { test } from "node:test";

import { serveView } from "../lib/handler.js";
import { fakeGitHub, repo } from "./fake-github.js";

const junit = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <properties>
    <property name="commit" value="e76ac93c0ffee"/>
    <property name="time" value="2026-10-24T14:52:07.000Z"/>
    <property name="position" value="0"/>
  </properties>
  <testsuite name="app / resorts" tests="2" failures="1" skipped="0">
    <testcase classname="resorts/a_test.dart" name="lists resorts"/>
    <testcase classname="resorts/a_test.dart" name="pulls to refresh">
      <failure/>
    </testcase>
  </testsuite>
</testsuites>
`;

const branchRun = { id: 7, number: 212, branch: "spec/c8", artifacts: { "junit-linux": { "app.xml": junit } } };

const serve = (url, { runs = [branchRun], deployment = "preview" } = {}) =>
  serveView(new Request(url), { fetch: fakeGitHub({ runs }), token: "t0ken", repo, deployment });

test("a preview shows a named run's tests by folder, with the folder roll-up and the commit and time, cached for minutes", async () => {
  const response = await serve("https://preview.example/api/view?run=7");

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "public, s-maxage=300");
  const view = await response.json();
  assert.equal(view.kind, "run");
  assert.deepEqual(view.header, {
    commit: "e76ac93",
    ran: "Sat 24 Oct 2026, 14:52 UTC",
    run: { number: 212, url: "https://github.com/o/r/actions/runs/7" },
    published: false,
  });
  assert.deepEqual(view.folders, [
    {
      name: "app / resorts",
      open: true,
      rollup: { status: "failed", count: 1, of: 2 },
      lines: [{ name: "lists resorts", status: "passed" }, { name: "pulls to refresh", status: "failed" }],
    },
  ]);
});
