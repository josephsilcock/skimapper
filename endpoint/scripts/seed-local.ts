// Seeds local (Miniflare) R2 with the skeleton message document.
//   node scripts/seed-local.ts --persist-to <dir> --message <text>
//   node scripts/seed-local.ts --persist-to <dir> --malformed      (a body that is not an envelope)
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";

import { skeletonMessageKey } from "../src/artefact-layout.ts";

const { values } = parseArgs({
  options: {
    "persist-to": { type: "string" },
    message: { type: "string" },
    malformed: { type: "boolean" },
  },
});
const persistTo = required(values["persist-to"], "--persist-to");
const body = values.malformed ? "this is not an envelope" : JSON.stringify(messageDocument());

const file = join(mkdtempSync(join(tmpdir(), "seed-")), "document.json");
writeFileSync(file, body);

execFileSync(
  "npx",
  ["wrangler", "r2", "object", "put", `skimapper-artefacts/${skeletonMessageKey}`,
    "--local", "--persist-to", persistTo, "--file", file, "--content-type", "application/json"],
  { stdio: ["ignore", "ignore", "inherit"], cwd: join(import.meta.dirname, "..") },
);

function messageDocument() {
  return {
    kind: "skeleton-message",
    schemaVersion: 1,
    dataVersion: new Date().toISOString().slice(0, 10),
    data: { message: required(values.message, "--message") },
  };
}

function required(value: string | undefined, flag: string): string {
  if (!value) throw new Error(`${flag} is required`);
  return value;
}
