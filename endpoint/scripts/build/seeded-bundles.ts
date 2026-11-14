import { existsSync } from "node:fs";
import { join } from "node:path";

import { curatedResortIds } from "./curated.ts";
import { fixtureBundleDir } from "./fixture.ts";

export type SeededBundle = { resortId: string; bundleDir: string };

// With RESORT_DATA=built every curated resort serves its build output; there is no silent
// fallback to the fixture.
export function builtBundles(resortIds: string[], buildOutputDir: string): SeededBundle[] {
  const bundles = resortIds.map((resortId) => ({ resortId, bundleDir: join(buildOutputDir, resortId) }));
  const missing = bundles.filter(({ bundleDir }) => !existsSync(join(bundleDir, "manifest.json")));
  if (missing.length) {
    throw new Error(`no build output for ${missing.map(({ resortId }) => resortId).join(", ")}: run node scripts/build-resorts.ts`);
  }
  return bundles;
}

export type ResortData = "fixture" | "built";

const buildOutputDir = join(import.meta.dirname, "..", "..", "build-output");

// Single home for which bundle the local endpoint serves under which resort id.
export function seededBundles(resortData: ResortData): SeededBundle[] {
  if (resortData === "built") return builtBundles(curatedResortIds(), buildOutputDir);
  return [{ resortId: "paradiski", bundleDir: fixtureBundleDir }];
}
