// Full sweep: node tools/sweep/main.ts [--layers <id,…>] — the chosen layers (default all), red unless
// every one ran tests and passed.
import { join } from "node:path";

import { listSwitch, selectLayers, sweepLayers } from "./layers.ts";
import { runSweep, summarise } from "./sweep.ts";

const repoDir = join(import.meta.dirname, "..", "..");
const resultsDir = join(repoDir, "test-results");

const layers = selectLayers(sweepLayers(repoDir), listSwitch(process.argv.slice(2), "--layers"));
const result = await runSweep({ resultsDir, layers });
process.stdout.write(summarise(result));
process.stdout.write(`(layer logs in ${join(resultsDir, "sweep")})\n`);
process.exitCode = result.ok ? 0 : 1;
