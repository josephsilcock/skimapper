// Nightly gate: node tools/sweep/gate.ts --sha <head> --run <this run id> <runs.json> <markers.json>
// The JSON files are GitHub's answers for this workflow's scheduled runs on <head> and for the
// nightly-verdict artifacts. Writes swept=true|false to $GITHUB_OUTPUT and says why in the run summary.
import { appendFileSync, readFileSync } from "node:fs";

import { listSwitch } from "./layers.ts";
import { nightlySweep, type SweepDecision } from "./skip.ts";

const args = process.argv.slice(2);
const option = (name: string): string => listSwitch(args, name)![0];
const [runsFile, markersFile] = args.slice(-2);
const headSha = option("--sha");

const decision = nightlySweep({
  headSha,
  currentRunId: Number(option("--run")),
  runs: JSON.parse(readFileSync(runsFile, "utf8")).workflow_runs,
  markers: JSON.parse(readFileSync(markersFile, "utf8")).artifacts,
});

const line = explain(decision);
process.stdout.write(line);
appendFileSync(process.env.GITHUB_STEP_SUMMARY!, line);
appendFileSync(process.env.GITHUB_OUTPUT!, `swept=${decision.swept}\n`);

function explain(decision: SweepDecision): string {
  return decision.swept
    ? `already swept by ${decision.sweptBy}\n`
    : `no nightly-verdict marker among ${decision.checkedRuns} earlier scheduled runs on ${headSha}\n`;
}
