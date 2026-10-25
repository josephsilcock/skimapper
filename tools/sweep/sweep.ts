import { spawn, spawnSync } from "node:child_process";
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { junitOf, type FolderRule, type TestRecord } from "./junit.ts";
import { runVerdict, type LayerVerdict } from "./verdict.ts";

export type Layer = {
  id: string;
  label: string;
  command: string[];
  cwd: string;
  countTests: (output: string) => number;
  results?: LayerResults;
};

// How a layer's per-test results are read after it runs, for the status site.
export type LayerResults = FolderRule & {
  reportArgs?: (reportFile: string) => string[];
  read: (run: { output: string; report: string }) => TestRecord[];
};

export type Culprit = { layer: string; reason: string };

export type SweepResult = { ok: boolean; culprits: Culprit[] };

export async function runSweep(options: { resultsDir: string; layers: Layer[]; commit?: string }): Promise<SweepResult> {
  const sweepDir = freshSweepDir(options.resultsDir);
  const verdicts: LayerVerdict[] = [];
  for (const layer of options.layers) {
    verdicts.push(await sweepLayer(layer, sweepDir, options.commit ?? ""));
  }
  const run = runVerdict(options.layers, verdicts);
  const result = { ok: run.ok, culprits: culpritsAmong(run.rows) };
  writeFileSync(join(sweepDir, "summary.txt"), summarise(result));
  writeFileSync(join(sweepDir, "results.json"), JSON.stringify(verdicts, null, 2) + "\n");
  return result;
}

export function summarise(result: SweepResult): string {
  if (result.ok) return "GREEN\n";
  return ["RED", ...result.culprits.map(({ layer, reason }) => `${layer}: ${reason}`)].join("\n") + "\n";
}

const culpritsAmong = (verdicts: LayerVerdict[]): Culprit[] =>
  verdicts.filter((verdict) => verdict.verdict === "red").map((verdict) => ({ layer: verdict.label, reason: verdict.reason ?? "" }));

async function sweepLayer(layer: Layer, sweepDir: string, commit: string): Promise<LayerVerdict> {
  const run = await runLayer(layer, { log: join(sweepDir, `${layer.label}.log`), report: join(sweepDir, `${layer.id}.report`) });
  if (layer.results) writeJunit(layer.id, layer.results, run, { sweepDir, commit });
  const reason = whyRed(layer, run);
  return reason
    ? { id: layer.id, label: layer.label, verdict: "red", reason }
    : { id: layer.id, label: layer.label, verdict: "green" };
}

function writeJunit(id: string, results: LayerResults, run: LayerRun, at: { sweepDir: string; commit: string }): void {
  const junit = junitOf(results.read(run), results, { commit: at.commit, time: new Date().toISOString() });
  mkdirSync(join(at.sweepDir, "junit"), { recursive: true });
  writeFileSync(join(at.sweepDir, "junit", `${id}.xml`), junit);
}

function freshSweepDir(resultsDir: string): string {
  const sweepDir = join(resultsDir, "sweep");
  rmSync(sweepDir, { recursive: true, force: true });
  mkdirSync(sweepDir, { recursive: true });
  return sweepDir;
}

function whyRed(layer: Layer, run: LayerRun): string | undefined {
  if (run.exitCode !== 0) return lastErrorLine(run.output) ?? `exited with code ${run.exitCode}`;
  if (layer.countTests(run.output) === 0) return "ran no tests";
  return undefined;
}

// The tools/ scripts report why they stopped on a line starting "error:" (tools/lib/common.sh fail).
const lastErrorLine = (output: string): string | undefined =>
  output.split("\n").findLast((line) => line.startsWith("error:"));

const readIfPresent = (file: string): string => (existsSync(file) ? readFileSync(file, "utf8") : "");

type LayerRun = { exitCode: number; output: string; report: string };

// Output goes straight to the log file and the run ends on the process's exit, not on its
// output closing: build daemons (Gradle, Kotlin) inherit the output and outlive the layer.
function runLayer(layer: Layer, files: { log: string; report: string }): Promise<LayerRun> {
  const log = openSync(files.log, "w");
  return new Promise((resolve, reject) => {
    const [program, ...args] = [...layer.command, ...(layer.results?.reportArgs?.(files.report) ?? [])];
    const child = spawn(program, args, { cwd: layer.cwd, stdio: ["ignore", log, log] });
    child.on("error", reject);
    child.on("exit", (code) => {
      closeSync(log);
      resolve({ exitCode: code ?? 1, output: readFileSync(files.log, "utf8"), report: readIfPresent(files.report) });
    });
  });
}

// The commit the status site names for this sweep's results.
export function commitUnderTest(repoDir: string, env: NodeJS.ProcessEnv): string {
  return env.GITHUB_SHA || spawnSync("git", ["rev-parse", "HEAD"], { cwd: repoDir, encoding: "utf8" }).stdout.trim();
}
