import { join } from "node:path";

import { UsageError } from "./cli.ts";
import { flutterRecords, patrolRecords, stripAnsi } from "./records.ts";
import type { Layer, LayerResults } from "./sweep.ts";

// The full sweep's layers, in order: fast, slow, then E2E per platform (docs/PIPELINE.md).
export function sweepLayers(repoDir: string): Layer[] {
  return positioned([
    {
      id: "app",
      label: "app",
      command: ["flutter", "test", "--reporter", "expanded"],
      cwd: join(repoDir, "app"),
      countTests: (output) => sumOf(output, /\+(\d+)(?: ~\d+)?(?: -(\d+))?: (?:All tests passed|Some tests failed)/g),
      results: {
        folder: "app",
        testRoot: join(repoDir, "app", "test"),
        reportArgs: (reportFile) => ["--file-reporter", `json:${reportFile}`],
        read: ({ report }) => flutterRecords(report),
      },
    },
    {
      id: "endpoint",
      label: "endpoint",
      command: ["npx", "vitest", "run"],
      cwd: join(repoDir, "endpoint"),
      countTests: (output) => sumOf(output, /Tests\s+.*?\((\d+)\)/g),
    },
    {
      id: "self-test",
      label: "sweep self-test",
      command: [process.execPath, "--test", "tools/sweep/"],
      cwd: repoDir,
      countTests: (output) => sumOf(output, /ℹ tests (\d+)/g),
    },
    {
      id: "status-site",
      label: "status-site",
      command: ["npm", "test"],
      cwd: join(repoDir, "status-site"),
      countTests: (output) => sumOf(output, /ℹ tests (\d+)/g),
    },
    e2eLayer(repoDir, "ios"),
    e2eLayer(repoDir, "android"),
  ]);
}

type UnplacedLayer = Omit<Layer, "results"> & { results?: Omit<LayerResults, "position"> };

// A layer's folders sit on the status site in the layer's sweep order.
const positioned = (layers: UnplacedLayer[]): Layer[] =>
  layers.map((layer, position) => ({ ...layer, results: layer.results && { ...layer.results, position } }));

// The layers a command line selects with the given switch: all when the switch is absent, otherwise the
// comma-separated ids after it, in sweep order. A missing, empty or unknown id is a UsageError.
export function layersFromArgs(layers: Layer[], args: string[], name: string): Layer[] {
  const switchAt = args.indexOf(name);
  if (switchAt === -1) return layers;
  const ids = args[switchAt + 1]?.split(",");
  if (!ids || ids.includes("")) throw new UsageError(`${name} needs a comma-separated list of layer ids (ids: ${idsOf(layers)})`);
  return selectLayers(layers, ids, name);
}

function selectLayers(layers: Layer[], ids: string[], name: string): Layer[] {
  const unknown = ids.find((id) => !layers.some((layer) => layer.id === id));
  if (unknown) throw new UsageError(`${name}: unknown layer '${unknown}' (ids: ${idsOf(layers)})`);
  return layers.filter((layer) => ids.includes(layer.id));
}

const idsOf = (layers: Layer[]): string => layers.map((layer) => layer.id).join(", ");

function e2eLayer(repoDir: string, platform: string): UnplacedLayer {
  const patrolRoot = join(repoDir, "app", "patrol_test");
  return {
    id: `e2e-${platform}`,
    label: `e2e (${platform})`,
    command: [join(repoDir, "tools", "e2e"), platform],
    cwd: repoDir,
    countTests: (output) => sumOf(stripAnsi(output), /^\W*(?:Successful|Failed): (\d+)/gm),
    results: {
      folder: platform,
      testRoot: patrolRoot,
      read: ({ output }) => patrolRecords(output, patrolRoot),
    },
  };
}

const sumOf = (output: string, pattern: RegExp): number =>
  [...output.matchAll(pattern)]
    .flatMap((match) => match.slice(1))
    .reduce((total, count) => total + Number(count ?? 0), 0);
