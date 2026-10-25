import { dirname, relative } from "node:path";

export type TestStatus = "passed" | "failed" | "skipped";

export type TestRecord = { file: string; name: string; status: TestStatus };

// Where a layer's tests appear on the status site: under its folder, then their path below its test root;
// position orders its folders among the layers'.
export type FolderRule = { folder: string; testRoot: string; position: number };

export type Stamp = { commit: string; time: string };

export function junitOf(records: readonly TestRecord[], rule: FolderRule, stamp: Stamp): string {
  const suites = Map.groupBy(records, (record) => folderOf(record, rule));
  const folders = [...suites.keys()].sort();
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    "<testsuites>",
    "  <properties>",
    ...Object.entries({ ...stamp, position: rule.position }).map(([name, value]) => `    <property name="${name}" value="${escapeXml(String(value))}"/>`),
    "  </properties>",
    ...folders.flatMap((folder) => testsuite(folder, suites.get(folder)!, rule)),
    "</testsuites>",
    "",
  ].join("\n");
}

function testsuite(folder: string, records: TestRecord[], rule: FolderRule): string[] {
  const count = (status: TestStatus) => records.filter((record) => record.status === status).length;
  return [
    `  <testsuite name="${escapeXml(folder)}" tests="${records.length}" failures="${count("failed")}" skipped="${count("skipped")}">`,
    ...records.flatMap((record) => testcase(record, rule)),
    "  </testsuite>",
  ];
}

function testcase(record: TestRecord, rule: FolderRule): string[] {
  const open = `    <testcase classname="${escapeXml(relative(rule.testRoot, record.file))}" name="${escapeXml(record.name)}"`;
  if (record.status === "passed") return [`${open}/>`];
  return [`${open}>`, `      <${record.status === "failed" ? "failure" : "skipped"}/>`, "    </testcase>"];
}

const folderOf = (record: TestRecord, rule: FolderRule): string => {
  const path = dirname(relative(rule.testRoot, record.file));
  return path === "." ? rule.folder : [rule.folder, ...path.split("/")].join(" / ");
};

const escapeXml = (text: string): string =>
  text.replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
