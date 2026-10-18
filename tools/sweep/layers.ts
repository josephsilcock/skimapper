import { join } from "node:path";

import type { Layer } from "./sweep.ts";

// The full sweep's layers, in order: fast, slow, then E2E per platform (docs/PIPELINE.md).
export function sweepLayers(repoDir: string): Layer[] {
  return [
    {
      name: "app",
      command: ["flutter", "test"],
      cwd: join(repoDir, "app"),
      countTests: (output) => sumOf(output, /\+(\d+)(?: ~\d+)?(?: -(\d+))?: (?:All tests passed|Some tests failed)/g),
    },
    {
      name: "endpoint",
      command: ["npx", "vitest", "run"],
      cwd: join(repoDir, "endpoint"),
      countTests: (output) => sumOf(output, /Tests\s+.*?\((\d+)\)/g),
    },
    {
      name: "sweep self-test",
      command: [process.execPath, "--test", "tools/sweep/"],
      cwd: repoDir,
      countTests: (output) => sumOf(output, /ℹ tests (\d+)/g),
    },
    e2eLayer(repoDir, "ios"),
    e2eLayer(repoDir, "android"),
  ];
}

function e2eLayer(repoDir: string, platform: string): Layer {
  return {
    name: "e2e",
    platform,
    command: [join(repoDir, "tools", "e2e"), platform],
    cwd: repoDir,
    countTests: (output) => sumOf(stripAnsi(output), /(?:Successful|Failed): (\d+)/g),
  };
}

const sumOf = (output: string, pattern: RegExp): number =>
  [...output.matchAll(pattern)]
    .flatMap((match) => match.slice(1))
    .reduce((total, count) => total + Number(count ?? 0), 0);

const stripAnsi = (text: string): string => text.replace(/\u001b\[[0-9;]*m/g, "");
