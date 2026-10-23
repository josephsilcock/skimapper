import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import { sweepLayers } from "./layers.ts";
import { runSweep, type Layer } from "./sweep.ts";

const stampLines = join(import.meta.dirname, "..", "lib", "stamp-lines.ts");

// Lines as the E2E run record captures them: through stamp-lines, under a tag and an E2E group.
const captured = (tag: string, group: string, lines: string): string =>
  spawnSync(process.execPath, [stampLines, tag, group], { input: lines, encoding: "utf8" }).stdout;

// An E2E layer whose run prints the given output, then exits with the given code.
const e2eLayerPrinting = (output: string, exitCode: number): Layer => ({
  ...sweepLayers("/repo").find((layer) => layer.id === "e2e-ios")!,
  command: [process.execPath, "-e", `process.stdout.write(${JSON.stringify(output)}); process.exit(${exitCode})`],
  cwd: tmpdir(),
});

test("captured lines that look like a test count or an error neither count nor become the layer's reason", async () => {
  const patrol = "✅ Successful: 2\n❌ Failed: 1\nerror: patrol reported failures\n";
  const lookalikes = captured("endpoint", "endpoint_malformed", "✅ Successful: 7\n❌ Failed: 3\nerror: boom\n");

  const result = await runSweep({
    resultsDir: join(tmpdir(), `run-record-${process.pid}`),
    layers: [e2eLayerPrinting(patrol + lookalikes, 1)],
  });

  assert.equal(e2eLayerPrinting("", 0).countTests(patrol + lookalikes), 3);
  assert.deepEqual(result.culprits, [{ layer: "e2e (ios)", reason: "error: patrol reported failures" }]);
});

test("each captured line is stamped with its tag, its E2E group and the UTC time to the millisecond", () => {
  const lines = captured("endpoint", "endpoint_malformed", "ready\nGET /v1/skeleton/message 200 OK (6ms)\n");

  assert.match(lines, /^\[endpoint endpoint_malformed \d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z\] ready\n\[endpoint endpoint_malformed \d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z\] GET \/v1\/skeleton\/message 200 OK \(6ms\)\n$/);
});
