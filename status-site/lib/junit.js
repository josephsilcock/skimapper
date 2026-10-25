import { XMLParser } from "fast-xml-parser";

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "",
  isArray: (name) => ["property", "testsuite", "testcase"].includes(name),
});

// One layer's results in the sweep's normalised JUnit (tools/sweep/junit.ts writes it).
export function readJunit(xml) {
  const { testsuites } = parser.parse(xml);
  const properties = Object.fromEntries(testsuites.properties.property.map(({ name, value }) => [name, value]));
  return {
    commit: properties.commit,
    time: properties.time,
    position: Number(properties.position),
    folders: (testsuites.testsuite ?? []).map((suite) => ({ name: suite.name, tests: (suite.testcase ?? []).map(testOf) })),
  };
}

const testOf = (testcase) => ({ name: testcase.name, file: testcase.classname, status: statusOf(testcase) });

const statusOf = (testcase) => ("failure" in testcase ? "failed" : "skipped" in testcase ? "skipped" : "passed");
