// Single home for the R2 key layout (C4 design § 3): mutable "latest" JSON documents vs
// immutable content-addressed parts.
export const latestDocumentKey = (name: string): string => `latest/${name}.json`;

export const skeletonMessageKey = latestDocumentKey("skeleton-message");
