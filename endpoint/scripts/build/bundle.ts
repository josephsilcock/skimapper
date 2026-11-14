import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// A resort bundle on disk: the manifest's data as `manifest.json`, and each part under
// `parts/<sha256>`, the shape seed-local publishes.
export type PartRole = "pistes" | "basemap" | "terrain";
export type Bounds = [west: number, south: number, east: number, north: number];
export type ManifestPart = { role: PartRole; sha256: string; size: number };
export type Manifest = { bounds: Bounds; credits: string[]; parts: ManifestPart[] };

export type BundleContents = { bounds: Bounds; credits: string[]; parts: { role: PartRole; bytes: Uint8Array }[] };

export function writeBundle(dir: string, { bounds, credits, parts }: BundleContents): void {
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(join(dir, "parts"), { recursive: true });
  const manifest: Manifest = { bounds, credits, parts: parts.map(({ role, bytes }) => pinned(role, bytes)) };
  parts.forEach(({ bytes }, i) => writeFileSync(partPath(dir, manifest.parts[i].sha256), bytes));
  writeFileSync(join(dir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
}

export const readManifest = (dir: string): Manifest => JSON.parse(readFileSync(join(dir, "manifest.json"), "utf8"));

export const partPath = (dir: string, sha256: string): string => join(dir, "parts", sha256);

const pinned = (role: PartRole, bytes: Uint8Array): ManifestPart => ({
  role,
  sha256: createHash("sha256").update(bytes).digest("hex"),
  size: bytes.byteLength,
});
