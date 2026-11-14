// Seeds local (Miniflare) R2 with the curated catalogue (or an E2E variant of it) and resort bundles.
//   node scripts/seed-local.ts --persist-to <dir>                        (the fixture, and its broken variants)
//   node scripts/seed-local.ts --persist-to <dir> --resort-data built    (each resort's build output)
//   node scripts/seed-local.ts --persist-to <dir> --extra-area <name>  (the catalogue gains an area)
//   node scripts/seed-local.ts --persist-to <dir> --unknown-version    (a schema version no app knows)
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";

import { catalogueKey, partKey, resortManifestKey } from "../src/artefact-layout.ts";
import { buildEnvelope } from "../src/envelope.ts";
import { partPath, readManifest, type Manifest } from "./build/bundle.ts";
import { curatedCatalogue, resortAreas } from "./build/curated.ts";
import { seededBundles, type ResortData, type SeededBundle } from "./build/seeded-bundles.ts";

const endpointDir = join(import.meta.dirname, "..");

const { values } = parseArgs({
  options: {
    "persist-to": { type: "string" },
    "extra-area": { type: "string" },
    "unknown-version": { type: "boolean" },
    "resort-data": { type: "string", default: "fixture" },
  },
});
const persistTo = required(values["persist-to"], "--persist-to");

put(catalogueKey, buildEnvelope("catalogue", values["unknown-version"] ? 999 : 1, catalogue()));
resortAreas();
for (const bundle of seededBundles(resortData(values["resort-data"]))) publishBundle(bundle);

// The curated catalogue, or an E2E variant derived from it.
function catalogue(): { resorts: unknown[] } {
  const curated = curatedCatalogue();
  const extraArea = values["extra-area"];
  if (!extraArea) return curated;
  return { resorts: [...curated.resorts, { id: "extra-area", name: extraArea, countries: ["France"], centre: { lat: 45.9, lon: 6.87 } }] };
}

// Parts before the manifest that pins them, so a published manifest never names a missing part.
function publishBundle({ resortId, bundleDir, variant }: SeededBundle): void {
  const manifest = readManifest(bundleDir);
  const pins = variant === "hash-mismatch" ? withMismatchedPistes(manifest) : manifest;
  manifest.parts.forEach(({ sha256 }, i) => {
    putFile(partKey(pins.parts[i].sha256), partPath(bundleDir, sha256), "application/octet-stream");
  });
  put(resortManifestKey(resortId), buildEnvelope("resort-manifest", variant === "unknown-version" ? 999 : 1, pins));
}

// The pistes part served under a hash its bytes don't have, at their own size.
function withMismatchedPistes(manifest: Manifest): Manifest {
  const mismatched = createHash("sha256").update("not the pistes part").digest("hex");
  return {
    ...manifest,
    parts: manifest.parts.map((part) => (part.role === "pistes" ? { ...part, sha256: mismatched } : part)),
  };
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

function resortData(value: string | undefined): ResortData {
  if (value === "fixture" || value === "built") return value;
  throw new Error(`--resort-data must be fixture or built (got ${value})`);
}

function required(value: string | undefined, flag: string): string {
  if (!value) throw new Error(`${flag} is required`);
  return value;
}
