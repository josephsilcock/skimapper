import { catalogueKey, skeletonMessageKey } from "./artefact-layout.ts";

const documentRoutes: Record<string, string> = {
  "/v1/skeleton/message": skeletonMessageKey,
  "/v1/catalogue": catalogueKey,
};

export default {
  async fetch(request, env): Promise<Response> {
    const key = documentRoutes[new URL(request.url).pathname];
    return key ? serveDocument(env.ARTEFACTS, key) : notFound();
  },
} satisfies ExportedHandler<Env>;

async function serveDocument(artefacts: R2Bucket, key: string): Promise<Response> {
  const document = await artefacts.get(key);
  if (!document) return notFound();
  return new Response(document.body, { headers: { "content-type": "application/json" } });
}

const notFound = (): Response => new Response("not found", { status: 404 });
