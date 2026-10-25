// The test lines of one run, from the JUnit reports (lib/junit.js) of its test jobs.
export function linesOfRun(reports) {
  return {
    commit: reports[0]?.commit,
    time: reports.map((report) => report.time).sort().at(-1),
    folders: foldersInOrder(reports).map((folder) => ({ name: folder.name, lines: folder.tests.map(lineOf) })),
  };
}

// Layer order (each report's position), then path.
const foldersInOrder = (reports) =>
  reports
    .flatMap((report) => report.folders.map((folder) => ({ ...folder, position: report.position })))
    .sort((a, b) => a.position - b.position || a.name.localeCompare(b.name));

const lineOf = ({ name, status }) => ({ name, status });
