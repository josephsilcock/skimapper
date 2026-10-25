import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

import { readJunit } from "../lib/junit.js";

// Written by the sweep's serialiser (tools/sweep/junit.ts), whose own test writes this same file.
const sharedExample = readFileSync(join(import.meta.dirname, "junit-example.xml"), "utf8");

test("the shared JUnit example reads as its stamp and its folders' tests, each with its file and status", () => {
  assert.deepEqual(readJunit(sharedExample), {
    commit: "e76ac93c0ffee",
    time: "2026-10-24T14:52:07.000Z",
    position: 0,
    folders: [
      { name: "app", tests: [{ name: "the app logs its launch once", file: "main_test.dart", status: "passed" }] },
      {
        name: "app / resorts",
        tests: [
          { name: 'lists each resort & its "countries" <sorted>', file: "resorts/catalogue_test.dart", status: "passed" },
          { name: "pulling the list down fetches again", file: "resorts/catalogue_test.dart", status: "failed" },
          { name: "a corrupt saved copy counts as nothing saved", file: "resorts/resort_list_view_test.dart", status: "skipped" },
        ],
      },
    ],
  });
});
