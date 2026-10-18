import assert from "node:assert/strict";
import { test } from "node:test";

import { nightlySweep, type Marker, type ScheduledRun } from "./skip.ts";

const head = "c0ffee";
const run = (id: number, headSha = head): ScheduledRun => ({ id, head_sha: headSha, html_url: `https://runs/${id}` });
const marker = (runId: number, expired = false): Marker => ({ expired, workflow_run: { id: runId } });

test("a head an earlier nightly left a marker on is already swept, by that run", () => {
  const decision = nightlySweep({ headSha: head, currentRunId: 9, runs: [run(7), run(8)], markers: [marker(7)] });

  assert.deepEqual(decision, { swept: true, sweptBy: "https://runs/7" });
});

test("an expired marker does not count, so the head is swept again", () => {
  const decision = nightlySweep({ headSha: head, currentRunId: 9, runs: [run(7)], markers: [marker(7, true)] });

  assert.deepEqual(decision, { swept: false, checkedRuns: 1 });
});

test("only earlier scheduled runs on this head are checked, so another commit's marker does not count", () => {
  const decision = nightlySweep({
    headSha: head,
    currentRunId: 9,
    runs: [run(6, "beef"), run(7), run(9)],
    markers: [marker(6)],
  });

  assert.deepEqual(decision, { swept: false, checkedRuns: 1 });
});
