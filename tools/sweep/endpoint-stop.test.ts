import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, openSync, readFileSync, writeFileSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const toolsDir = join(import.meta.dirname, "..");

const freePort = (): Promise<number> =>
  new Promise((resolve) => {
    const server = createServer().listen(0, "127.0.0.1", () => {
      const { port } = server.address() as { port: number };
      server.close(() => resolve(port));
    });
  });

// A stand-in for wrangler shaped like CI's: the endpoint process waits on a middle parent that
// exits on SIGTERM, whose child (workerd's place) serves HTTP on the port.
const standInEndpoint = (): string => {
  const dir = mkdtempSync(join(tmpdir(), "endpoint-stop-"));
  writeFileSync(
    join(dir, "server.mjs"),
    `import { createServer } from "node:http";
import { writeFileSync } from "node:fs";
writeFileSync("${dir}/server.pid", String(process.pid));
createServer((_, response) => response.end("stand-in")).listen(Number(process.env.ENDPOINT_PORT), "127.0.0.1");
process.on("SIGTERM", () => process.stdout.write("stand-in shutting down\\n", () => process.exit(0)));
`,
  );
  writeFileSync(join(dir, "middle.sh"), `echo $$ > "${dir}/middle.pid"; node "${dir}/server.mjs" & wait\n`);
  writeFileSync(join(dir, "endpoint.sh"), `echo $$ > "${dir}/endpoint.pid"; bash "${dir}/middle.sh" & wait\n`);
  return dir;
};

const signalledPids = (output: string): string[] | undefined =>
  /^\[harness - [^\]]+\] stopping the endpoint: signalled PIDs ([\d ]+)$/m.exec(output)?.[1].split(" ");

const standInPids = (dir: string): string[] =>
  ["endpoint", "middle", "server"].map((name) => readFileSync(join(dir, `${name}.pid`), "utf8").trim());

// Starts the stand-in through the real start_endpoint beside a sibling process, stops it through the
// real stop_endpoint, then reports whether the port answers and the sibling lives. Output goes to a
// file, not a pipe, so a survivor holding it can't keep the run open; everything the run started is
// killed afterwards through its own process group.
const startThenStop = async () => {
  const standIn = standInEndpoint();
  const script = `
source "${toolsDir}/lib/common.sh"
source "${toolsDir}/lib/endpoint.sh"
run_endpoint_server() { exec bash "${standIn}/endpoint.sh"; }
sleep 60 &
sibling=$!
start_endpoint "${standIn}"
stop_endpoint
if curl -s -o /dev/null "$ENDPOINT_URL/"; then echo "after stop: port answers"; else echo "after stop: port free"; fi
if kill -0 "$sibling" 2>/dev/null; then echo "after stop: sibling alive"; else echo "after stop: sibling gone"; fi
`;
  const output = join(standIn, "output.log");
  const outputFd = openSync(output, "w");
  const run = spawnSync("bash", ["-c", script], {
    env: { ...process.env, ENDPOINT_PORT: String(await freePort()) },
    stdio: ["ignore", outputFd, outputFd],
    detached: true,
    timeout: 30_000,
  });
  try {
    process.kill(-run.pid!, "SIGKILL");
  } catch {}
  return { output: readFileSync(output, "utf8"), pids: standInPids(standIn) };
};

test("stopping the endpoint frees its port even when the port's holder outlives its parent, and leaves siblings running", async () => {
  const { output } = await startThenStop();

  assert.match(output, /after stop: port free/, output);
  assert.match(output, /after stop: sibling alive/, output);
});

test("stopping the endpoint records, as a stamped harness line, the PIDs it signals: the endpoint's processes only", async () => {
  const { output, pids } = await startThenStop();

  assert.deepEqual(signalledPids(output)?.toSorted(), pids.toSorted(), output);
});

test("stopping the endpoint leaves its output stamper running, so the endpoint's shutdown lines are recorded", async () => {
  const { output } = await startThenStop();

  assert.match(output, /^\[endpoint - [^\]]+\] stand-in shutting down$/m, output);
});
