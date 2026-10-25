import assert from "node:assert/strict";
import { test } from "node:test";

import { viewOf } from "../lib/view.js";

const run = { number: 212, url: "https://github.com/o/r/actions/runs/1", published: true };
const lines = (folders) => ({ commit: "e76ac93c0ffee1234", time: "2026-10-24T14:52:07.000Z", folders });

test("a folder with a failure opens, flagged with its failure count; an all-passed folder stays closed, n of n", () => {
  const view = viewOf(
    lines([
      { name: "app", lines: [{ name: "a", status: "passed" }, { name: "b", status: "passed" }] },
      { name: "app / resorts", lines: [{ name: "c", status: "passed" }, { name: "d", status: "failed" }] },
    ]),
    run,
  );

  assert.deepEqual(
    view.folders.map(({ name, open, rollup }) => ({ name, open, rollup })),
    [
      { name: "app", open: false, rollup: { status: "passed", count: 2, of: 2 } },
      { name: "app / resorts", open: true, rollup: { status: "failed", count: 1, of: 2 } },
    ],
  );
});

test("the header names the commit tested, when the sweep ran in UTC, and the run, and says whether it was published", () => {
  const view = viewOf(lines([]), { ...run, published: false });

  assert.deepEqual(view.header, {
    commit: "e76ac93",
    ran: "Sat 24 Oct 2026, 14:52 UTC",
    run: { number: 212, url: "https://github.com/o/r/actions/runs/1" },
    published: false,
  });
});
