import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, it } from "vitest";

import { fixtureBundleDir, fixturePistes } from "../../scripts/build/fixture.ts";
import { pistesPartBytes } from "../../scripts/build/pistes-format.ts";

it("the committed fixture's pistes part is the normaliser's output over the sample", () => {
  const manifest = JSON.parse(readFileSync(join(fixtureBundleDir, "manifest.json"), "utf8"));
  const pistesPart = manifest.parts.find((part: { role: string }) => part.role === "pistes");
  const committed = join(fixtureBundleDir, "parts", pistesPart?.sha256 ?? "missing");

  expect(existsSync(committed), "committed pistes part").toBe(true);
  expect(readFileSync(committed)).toEqual(Buffer.from(pistesPartBytes(fixturePistes())));
});
