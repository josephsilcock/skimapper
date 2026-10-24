// Single home for the envelope shape on the TypeScript side (C4 design § 3): every JSON document
// is `{kind, schemaVersion, dataVersion, data}`, schemaVersion counted per kind.
export type Envelope<Data> = { kind: string; schemaVersion: number; dataVersion: string; data: Data };

export const buildEnvelope = <Data>(
  kind: string,
  schemaVersion: number,
  data: Data,
  dataVersion: string = new Date().toISOString().slice(0, 10),
): Envelope<Data> => ({ kind, schemaVersion, dataVersion, data });
