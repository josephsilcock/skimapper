import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

import { junitOf } from "./junit.ts";

const repoDir = join(import.meta.dirname, "..", "..");
// The JUnit shape the status site reads; its own tests read this same file.
const sharedExample = readFileSync(join(repoDir, "status-site", "test", "junit-example.xml"), "utf8");

test("test records are written as the shared JUnit example: a testsuite per folder, the file as classname, commit and time on the root", () => {
  const testRoot = "/repo/app/test";
  const records = [
    { file: "/repo/app/test/resorts/catalogue_test.dart", name: 'lists each resort & its "countries" <sorted>', status: "passed" },
    { file: "/repo/app/test/main_test.dart", name: "the app logs its launch once", status: "passed" },
    { file: "/repo/app/test/resorts/catalogue_test.dart", name: "pulling the list down fetches again", status: "failed" },
    { file: "/repo/app/test/resorts/resort_list_view_test.dart", name: "a corrupt saved copy counts as nothing saved", status: "skipped" },
  ] as const;

  const junit = junitOf(records, { folder: "app", testRoot, position: 0 }, { commit: "e76ac93c0ffee", time: "2026-10-24T14:52:07.000Z" });

  assert.equal(junit, sharedExample);
});
