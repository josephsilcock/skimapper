// The harness side of the E2E run record: copies stdin to stdout line by line, each line under the
// tag and E2E group given as arguments and the UTC time it arrived, to the millisecond (the app's
// lines use the same format, app/lib/endpoint/run_record.dart).
import { createInterface } from "node:readline";

const [tag, group] = process.argv.slice(2);

for await (const line of createInterface({ input: process.stdin })) {
  process.stdout.write(`[${tag} ${group} ${new Date().toISOString()}] ${line}\n`);
}
