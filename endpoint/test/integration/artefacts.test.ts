import { env, exports } from "cloudflare:workers";
import { expect, it } from "vitest";

import { catalogueKey, skeletonMessageKey } from "../../src/artefact-layout.ts";
import { buildEnvelope } from "../../src/envelope.ts";

it("serves the stored skeleton message document from R2 under /v1/", async () => {
  const document = buildEnvelope("skeleton-message", 1, { message: "hello" });
  await env.ARTEFACTS.put(skeletonMessageKey, JSON.stringify(document));

  const response = await exports.default.fetch("http://endpoint/v1/skeleton/message");

  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toBe("application/json");
  expect(await response.json()).toEqual(document);
});

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
