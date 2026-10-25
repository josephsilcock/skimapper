// CI report: node tools/sweep/report.ts [--expect <id,…>] <results-dir> — combines the results.json each
// job's sweep wrote under <results-dir> against the expected layers (default all) into a per-layer table,
// printed and (under GitHub Actions) added to the run summary; red unless every expected layer is green.
import { appendFileSync, existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";

import { runCli } from "./cli.ts";
import { layersFromArgs, sweepLayers } from "./layers.ts";
import { runVerdict, type LayerVerdict } from "./verdict.ts";

const repoDir = join(import.meta.dirname, "..", "..");
const args = process.argv.slice(2);

await runCli(() => {
  const expected = layersFromArgs(sweepLayers(repoDir), args, "--expect");
  const verdicts = readResults(args.at(-1)!);
  const run = runVerdict(expected, verdicts);
  const table = summaryTable(run.rows);
  process.stdout.write(table);
  addToStepSummary(table);
  process.exitCode = run.ok ? 0 : 1;
});

// Only under GitHub Actions; a local run has just the stdout table.
function addToStepSummary(table: string): void {
  const summaryFile = process.env.GITHUB_STEP_SUMMARY;
  if (summaryFile) appendFileSync(summaryFile, table);
}

function readResults(root: string): LayerVerdict[] {
  if (!existsSync(root)) return [];
  return readdirSync(root, { recursive: true, encoding: "utf8" })
    .filter((path) => basename(path) === "results.json")
    .flatMap((path) => JSON.parse(readFileSync(join(root, path), "utf8")) as LayerVerdict[]);
}

function summaryTable(rows: LayerVerdict[]): string {
  const lines = rows.map(({ label, verdict, reason }) =>
    `| ${label} | ${verdict === "green" ? "🟢 green" : "🔴 red"} | ${reason ?? ""} |`);
  return ["| Layer | Verdict | Reason |", "|---|---|---|", ...lines].join("\n") + "\n";
}
