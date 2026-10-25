import { env, exports } from "cloudflare:workers";
import { expect, it } from "vitest";

import { catalogueKey } from "../../src/artefact-layout.ts";
import { buildEnvelope } from "../../src/envelope.ts";

it("serves the stored catalogue document from R2 under /v1/catalogue", async () => {
  const document = buildEnvelope("catalogue", 1, {
    resorts: [{ name: "Paradiski", countries: ["France"], centre: { lat: 45.55, lon: 6.8 } }],
  });
  await env.ARTEFACTS.put(catalogueKey, JSON.stringify(document));

  const response = await exports.default.fetch("http://endpoint/v1/catalogue");

  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toBe("application/json");
  expect(await response.json()).toEqual(document);
});
