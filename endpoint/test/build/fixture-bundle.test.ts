import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { expect, it } from "vitest";

import { boundsOf } from "../../scripts/build/bounds.ts";
import { partPath, readManifest } from "../../scripts/build/bundle.ts";
import { fixtureBundleDir, fixturePistes } from "../../scripts/build/fixture.ts";
import { pistesPartBytes } from "../../scripts/build/pistes-format.ts";

const manifest = readManifest(fixtureBundleDir);
const committedPart = (role: string): Buffer => {
  const pin = manifest.parts.find((part) => part.role === role);
  const path = partPath(fixtureBundleDir, pin?.sha256 ?? "missing");
  expect(existsSync(path), `committed ${role} part`).toBe(true);
  return readFileSync(path);
};

it("the committed fixture's pistes part is the normaliser's output over the sample", () => {
  expect(committedPart("pistes")).toEqual(Buffer.from(pistesPartBytes(fixturePistes())));
});

it("the committed fixture pins its pistes, basemap and terrain, each part matching its pin", () => {
  expect(manifest.parts.map((part) => part.role)).toEqual(["pistes", "basemap", "terrain"]);
  for (const { role, sha256, size } of manifest.parts) {
    const bytes = committedPart(role);
    expect(bytes.byteLength, role).toBe(size);
    expect(createHash("sha256").update(bytes).digest("hex"), role).toBe(sha256);
  }
});

it("the committed fixture is framed on its pistes' bounds", () => {
  expect(manifest.bounds).toEqual(boundsOf(fixturePistes()));
});
