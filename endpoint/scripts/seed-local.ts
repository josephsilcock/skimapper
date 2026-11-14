// Seeds local (Miniflare) R2 with the curated catalogue (or an E2E variant of it) and the fixture resort bundle.
//   node scripts/seed-local.ts --persist-to <dir>
//   node scripts/seed-local.ts --persist-to <dir> --extra-area <name>  (the catalogue gains an area)
//   node scripts/seed-local.ts --persist-to <dir> --unknown-version    (a schema version no app knows)
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";

import { catalogueKey, partKey, resortManifestKey } from "../src/artefact-layout.ts";
import { buildEnvelope } from "../src/envelope.ts";
import { partPath, readManifest } from "./build/bundle.ts";
import { fixtureBundleDir } from "./build/fixture.ts";

const endpointDir = join(import.meta.dirname, "..");

const { values } = parseArgs({
  options: {
    "persist-to": { type: "string" },
    "extra-area": { type: "string" },
    "unknown-version": { type: "boolean" },
  },
});
const persistTo = required(values["persist-to"], "--persist-to");

put(catalogueKey, buildEnvelope("catalogue", values["unknown-version"] ? 999 : 1, catalogue()));
publishBundle("paradiski", fixtureBundleDir);

// The curated catalogue, or an E2E variant derived from it.
function catalogue(): { resorts: unknown[] } {
  const curated = JSON.parse(readFileSync(join(endpointDir, "catalogue", "curated.json"), "utf8"));
  const extraArea = values["extra-area"];
  if (!extraArea) return curated;
  return { resorts: [...curated.resorts, { id: "extra-area", name: extraArea, countries: ["France"], centre: { lat: 45.9, lon: 6.87 } }] };
}

// Parts before the manifest that pins them, so a published manifest never names a missing part.
function publishBundle(resortId: string, bundleDir: string): void {
  const manifest = readManifest(bundleDir);
  for (const { sha256 } of manifest.parts) {
    putFile(partKey(sha256), partPath(bundleDir, sha256), "application/octet-stream");
  }
  put(resortManifestKey(resortId), buildEnvelope("resort-manifest", 1, manifest));
}

function put(key: string, document: unknown): void {
  const file = join(mkdtempSync(join(tmpdir(), "seed-")), "document.json");
  writeFileSync(file, JSON.stringify(document));
  putFile(key, file, "application/json");
}

function putFile(key: string, file: string, contentType: string): void {
  execFileSync(
    "npx",
    ["wrangler", "r2", "object", "put", `skimapper-artefacts/${key}`,
      "--local", "--persist-to", persistTo, "--file", file, "--content-type", contentType],
    { stdio: ["ignore", "ignore", "inherit"], cwd: endpointDir },
  );
}

function required(value: string | undefined, flag: string): string {
  if (!value) throw new Error(`${flag} is required`);
  return value;
}
