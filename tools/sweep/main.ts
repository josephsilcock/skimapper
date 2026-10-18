// Full sweep: node tools/sweep/main.ts — every layer, red unless every layer ran tests and passed.
import { join } from "node:path";

import { sweepLayers } from "./layers.ts";
import { runSweep, summarise } from "./sweep.ts";

const repoDir = join(import.meta.dirname, "..", "..");
const resultsDir = join(repoDir, "test-results");

const result = await runSweep({ resultsDir, layers: sweepLayers(repoDir) });
process.stdout.write(summarise(result));
process.stdout.write(`(layer logs in ${join(resultsDir, "sweep")})\n`);
process.exitCode = result.ok ? 0 : 1;
