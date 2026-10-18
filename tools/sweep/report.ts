// CI report: node tools/sweep/report.ts [--expect <id,…>] <results-dir> — combines the results.json each
// job's sweep wrote under <results-dir> against the expected layers (default all) into the run summary;
// red unless every expected layer is green.
import { appendFileSync, existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";

import { listSwitch, selectLayers, sweepLayers } from "./layers.ts";
import { runVerdict, type LayerVerdict } from "./verdict.ts";

const repoDir = join(import.meta.dirname, "..", "..");
const args = process.argv.slice(2);

const expected = selectLayers(sweepLayers(repoDir), listSwitch(args, "--expect"));
const verdicts = readResults(args.at(-1)!);
const run = runVerdict(expected, verdicts);
const table = summaryTable(run.rows);
process.stdout.write(table);
appendFileSync(process.env.GITHUB_STEP_SUMMARY!, table);
process.exitCode = run.ok ? 0 : 1;

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
