import { catalogueKey, partKey, resortManifestKey } from "./artefact-layout.ts";

type Artefact = { key: string; contentType: string };

const resortManifestRoute = /^\/v1\/resorts\/([a-z0-9-]+)\/manifest$/;
const partRoute = /^\/v1\/parts\/([0-9a-f]{64})$/;

export default {
  async fetch(request, env): Promise<Response> {
    const artefact = routed(new URL(request.url).pathname);
    return artefact ? serve(env.ARTEFACTS, artefact) : notFound();
  },
} satisfies ExportedHandler<Env>;

// Documents are JSON envelopes under mutable keys; parts are content-addressed bytes.
function routed(path: string): Artefact | undefined {
  if (path === "/v1/catalogue") return document(catalogueKey);
  const resortId = resortManifestRoute.exec(path)?.[1];
  if (resortId) return document(resortManifestKey(resortId));
  const sha256 = partRoute.exec(path)?.[1];
  if (sha256) return { key: partKey(sha256), contentType: "application/octet-stream" };
  return undefined;
}

const document = (key: string): Artefact => ({ key, contentType: "application/json" });

async function serve(artefacts: R2Bucket, { key, contentType }: Artefact): Promise<Response> {
  const object = await artefacts.get(key);
  if (!object) return notFound();
  return new Response(object.body, { headers: { "content-type": contentType } });
}

const notFound = (): Response => new Response("not found", { status: 404 });
