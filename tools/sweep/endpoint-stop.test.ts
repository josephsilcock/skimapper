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

const shutsDown = `process.stdout.write("stand-in shutting down\\n", () => process.exit(0))`;
const ignoresIt = "{}";

// A stand-in for wrangler shaped like CI's: the endpoint process waits on a middle parent that
// exits on SIGTERM, whose child (workerd's place) serves HTTP on the port and answers SIGTERM as told.
const standInEndpoint = (onSigterm: string): string => {
  const dir = mkdtempSync(join(tmpdir(), "endpoint-stop-"));
  writeFileSync(
    join(dir, "server.mjs"),
    `import { createServer } from "node:http";
import { writeFileSync } from "node:fs";
writeFileSync("${dir}/server.pid", String(process.pid));
createServer((_, response) => response.end("stand-in")).listen(Number(process.env.ENDPOINT_PORT), "127.0.0.1");
process.on("SIGTERM", () => ${onSigterm});
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

// Runs the harness script against the stand-in, with the real tools/lib sourced and the real
// start_endpoint launching the stand-in, on a port of its own and a short stop limit. Output goes to
// a file, not a pipe, so a survivor holding it can't keep the run open; everything the run started is
// killed afterwards through its own process group.
const runAgainstStandIn = async (onSigterm: string, harness: string) => {
  const standIn = standInEndpoint(onSigterm);
  const script = `
source "${toolsDir}/lib/common.sh"
source "${toolsDir}/lib/endpoint.sh"
run_endpoint_server() { exec bash "${standIn}/endpoint.sh"; }
${harness}`;
  const output = join(standIn, "output.log");
  const outputFd = openSync(output, "w");
  const run = spawnSync("bash", ["-c", script], {
    env: { ...process.env, ENDPOINT_PORT: String(await freePort()), ENDPOINT_STOP_TIMEOUT_MS: "500" },
    stdio: ["ignore", outputFd, outputFd],
    detached: true,
    timeout: 30_000,
  });
  try {
    process.kill(-run.pid!, "SIGKILL");
  } catch {}
  return { status: run.status, output: readFileSync(output, "utf8"), pids: standInPids(standIn) };
};

// Starts and stops the stand-in beside a sibling process, then reports whether the port answers and
// the sibling lives.
const startThenStop = () =>
  runAgainstStandIn(
    shutsDown,
    `
sleep 60 &
sibling=$!
start_endpoint unused
stop_endpoint
if curl -s -o /dev/null "$ENDPOINT_URL/"; then echo "after stop: port answers"; else echo "after stop: port free"; fi
if kill -0 "$sibling" 2>/dev/null; then echo "after stop: sibling alive"; else echo "after stop: sibling gone"; fi
`,
  );

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

test("a stop whose endpoint keeps the port past the limit fails, with a port snapshot and an error naming the holder", async () => {
  const { status, output, pids } = await runAgainstStandIn(ignoresIt, "start_endpoint unused\nstop_endpoint");
  const server = pids[2];

  assert.equal(status, 1, output);
  assert.match(output, new RegExp(`^\\[port - [^\\]]+\\] \\S+ +${server} .*\\(LISTEN\\)$`, "m"));
  assert.match(output, new RegExp(`^error: .*${server}`, "m"));
});

test("a second stop after a failed one, as from an EXIT trap, is silent: the first error stays the only one", async () => {
  const { status, output } = await runAgainstStandIn(ignoresIt, "start_endpoint unused\ntrap stop_endpoint EXIT\nstop_endpoint");

  assert.equal(status, 1, output);
  assert.equal(output.match(/^error: /gm)?.length, 1, output);
});
