// Seeds local (Miniflare) R2 with the curated catalogue and, while it lasts, the skeleton message.
//   node scripts/seed-local.ts --persist-to <dir>                    (the catalogue only)
//   node scripts/seed-local.ts --persist-to <dir> --extra-area <name> (the catalogue gains an area)
//   node scripts/seed-local.ts --persist-to <dir> --message <text>
//   node scripts/seed-local.ts --persist-to <dir> --unknown-version  (a message this app can't read)
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";

import { catalogueKey, skeletonMessageKey } from "../src/artefact-layout.ts";
import { buildEnvelope } from "../src/envelope.ts";

const endpointDir = join(import.meta.dirname, "..");

const { values } = parseArgs({
  options: {
    "persist-to": { type: "string" },
    message: { type: "string" },
    "unknown-version": { type: "boolean" },
    "extra-area": { type: "string" },
  },
});
const persistTo = required(values["persist-to"], "--persist-to");

put(catalogueKey, buildEnvelope("catalogue", 1, catalogue()));
if (values["unknown-version"]) put(skeletonMessageKey, buildEnvelope("skeleton-message", 2, {}));
if (values.message) put(skeletonMessageKey, buildEnvelope("skeleton-message", 1, { message: values.message }));

// The curated catalogue, or an E2E variant derived from it.
function catalogue(): { resorts: unknown[] } {
  const curated = JSON.parse(readFileSync(join(endpointDir, "catalogue", "curated.json"), "utf8"));
  const extraArea = values["extra-area"];
  if (!extraArea) return curated;
  return { resorts: [...curated.resorts, { name: extraArea, countries: ["France"], centre: { lat: 45.9, lon: 6.87 } }] };
}

function put(key: string, document: unknown): void {
  const file = join(mkdtempSync(join(tmpdir(), "seed-")), "document.json");
  writeFileSync(file, JSON.stringify(document));
  execFileSync(
    "npx",
    ["wrangler", "r2", "object", "put", `skimapper-artefacts/${key}`,
      "--local", "--persist-to", persistTo, "--file", file, "--content-type", "application/json"],
    { stdio: ["ignore", "ignore", "inherit"], cwd: endpointDir },
  );
}

function required(value: string | undefined, flag: string): string {
  if (!value) throw new Error(`${flag} is required`);
  return value;
}
