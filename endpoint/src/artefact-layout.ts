// Single home for the R2 key layout (C4 design § 3): mutable "latest" JSON documents vs
// immutable content-addressed parts.
export const latestDocumentKey = (name: string): string => `latest/${name}.json`;

export const catalogueKey = latestDocumentKey("catalogue");

export const resortManifestKey = (resortId: string): string => latestDocumentKey(`resorts/${resortId}/manifest`);

export const partKey = (sha256: string): string => `parts/${sha256}`;
