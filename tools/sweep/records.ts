import { join } from "node:path";

import type { TestRecord, TestStatus } from "./junit.ts";

type FlutterEvent =
  | { type: "suite"; suite: { id: number; path: string } }
  | { type: "testStart"; test: { id: number; name: string; suiteID: number } }
  | { type: "testDone"; testID: number; result: "success" | "failure" | "error"; skipped: boolean; hidden: boolean }
  | { type: "start" | "allSuites" | "group" | "print" | "error" | "done" };

// `flutter test --file-reporter json:<file>`: one JSON event per line. Hidden tests are the runner's own
// ("loading <file>").
export function flutterRecords(report: string): TestRecord[] {
  const events = report.split("\n").filter(Boolean).map((line) => JSON.parse(line) as FlutterEvent);
  const files = new Map<number, string>();
  const started = new Map<number, { name: string; file: string }>();
  const records: TestRecord[] = [];
  for (const event of events) {
    if (event.type === "suite") files.set(event.suite.id, event.suite.path);
    if (event.type === "testStart") started.set(event.test.id, { name: event.test.name, file: files.get(event.test.suiteID)! });
    if (event.type === "testDone" && !event.hidden) records.push({ ...started.get(event.testID)!, status: flutterStatus(event) });
  }
  return records;
}

const flutterStatus = (done: { result: string; skipped: boolean }): TestStatus =>
  done.skipped ? "skipped" : done.result === "success" ? "passed" : "failed";

// Patrol's result lines (patrol_log TestEntry.pretty): a finished test as "<✅|❌> <name> (/<path>.dart) (<time>)",
// a skipped one as "⏩ <dotted path> <name>". Anchored to the line start, so an app log line ("flutter: …")
// cannot pass for a result.
export function patrolRecords(output: string, patrolRoot: string): TestRecord[] {
  return stripAnsi(output)
    .split("\n")
    .flatMap((line) => finishedPatrolTest(line, patrolRoot) ?? skippedPatrolTest(line, patrolRoot) ?? []);
}

function finishedPatrolTest(line: string, patrolRoot: string): TestRecord | undefined {
  const [, mark, name, path] = /^(✅|❌) (.+) \((\/[^()]+\.dart)\) \([^()]+\)$/.exec(line) ?? [];
  if (!mark) return undefined;
  return { file: join(patrolRoot, path), name, status: mark === "✅" ? "passed" : "failed" };
}

function skippedPatrolTest(line: string, patrolRoot: string): TestRecord | undefined {
  const [, dottedPath, name] = /^⏩ (\S+_test) (.+)$/.exec(line) ?? [];
  if (!dottedPath) return undefined;
  return { file: join(patrolRoot, `${dottedPath.replaceAll(".", "/")}.dart`), name, status: "skipped" };
}

export const stripAnsi = (text: string): string => text.replace(/\u001b\[[0-9;]*[A-Za-z]/g, "");
