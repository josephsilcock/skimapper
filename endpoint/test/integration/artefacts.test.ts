import { env, exports } from "cloudflare:workers";
import { expect, it } from "vitest";

import { skeletonMessageKey } from "../../src/artefact-layout.ts";

it("serves the stored skeleton message document from R2 under /v1/", async () => {
  const document = { kind: "skeleton-message", schemaVersion: 1, dataVersion: "2026-10-18", data: { message: "hello" } };
  await env.ARTEFACTS.put(skeletonMessageKey, JSON.stringify(document));

  const response = await exports.default.fetch("http://endpoint/v1/skeleton/message");

  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toBe("application/json");
  expect(await response.json()).toEqual(document);
});
