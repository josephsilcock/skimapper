import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, it } from "vitest";

import { fixtureBundleDir } from "../../scripts/build/fixture.ts";
import { builtBundles, seededBundles } from "../../scripts/build/seeded-bundles.ts";

const buildOutput = (...built: string[]): string => {
  const dir = mkdtempSync(join(tmpdir(), "build-output-"));
  for (const resortId of built) {
    mkdirSync(join(dir, resortId));
    writeFileSync(join(dir, resortId, "manifest.json"), "{}");
  }
  return dir;
};

it("seeds each curated resort's build output under its id", () => {
  const dir = buildOutput("paradiski", "les-3-vallees");

  expect(builtBundles(["paradiski", "les-3-vallees"], dir)).toEqual([
    { resortId: "paradiski", bundleDir: join(dir, "paradiski") },
    { resortId: "les-3-vallees", bundleDir: join(dir, "les-3-vallees") },
  ]);
});

it("fails naming every curated resort that has no build output", () => {
  const dir = buildOutput("les-3-vallees");

  expect(() => builtBundles(["paradiski", "les-3-vallees", "espace-san-bernardo"], dir)).toThrow(
    "no build output for paradiski, espace-san-bernardo: run node scripts/build-resorts.ts",
  );
});

it("by default seeds the fixture resort under Paradiski", () => {
  expect(seededBundles("fixture")).toEqual([{ resortId: "paradiski", bundleDir: fixtureBundleDir }]);
});
