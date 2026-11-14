import { env, exports } from "cloudflare:workers";
import { expect, it } from "vitest";

import { catalogueKey, partKey, resortManifestKey } from "../../src/artefact-layout.ts";
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

it("serves a resort's stored manifest from R2 under /v1/resorts/<id>/manifest", async () => {
  const manifest = buildEnvelope("resort-manifest", 1, { bounds: [6.7, 45.5, 6.9, 45.6], credits: [], parts: [] });
  await env.ARTEFACTS.put(resortManifestKey("paradiski"), JSON.stringify(manifest));

  const response = await exports.default.fetch("http://endpoint/v1/resorts/paradiski/manifest");

  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toBe("application/json");
  expect(await response.json()).toEqual(manifest);
});

it("serves a stored part's bytes from R2 under /v1/parts/<sha256>", async () => {
  const sha256 = "a".repeat(64);
  const bytes = new Uint8Array([0, 1, 2, 250]);
  await env.ARTEFACTS.put(partKey(sha256), bytes);

  const response = await exports.default.fetch(`http://endpoint/v1/parts/${sha256}`);

  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toBe("application/octet-stream");
  expect(new Uint8Array(await response.arrayBuffer())).toEqual(bytes);
});

it("answers 404 for a resort with no manifest, a part not stored, and a malformed hash", async () => {
  for (const path of ["/v1/resorts/nowhere/manifest", `/v1/parts/${"b".repeat(64)}`, "/v1/parts/not-a-hash"]) {
    const response = await exports.default.fetch(`http://endpoint${path}`);
    expect(response.status, path).toBe(404);
  }
});
