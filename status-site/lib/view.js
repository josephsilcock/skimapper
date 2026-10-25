// What the page shows for one run: every status and roll-up decided here, so the page only renders.
export function viewOf(lines, run) {
  return { header: headerOf(lines, run), folders: lines.folders.map(folderView) };
}

function headerOf(lines, run) {
  return {
    commit: lines.commit.slice(0, 7),
    ran: utcTime(lines.time),
    run: { number: run.number, url: run.url },
    published: run.published,
  };
}

const utcFormat = new Intl.DateTimeFormat("en-GB", {
  timeZone: "UTC",
  weekday: "short",
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

// "Sat 24 Oct 2026, 14:52 UTC"
function utcTime(iso) {
  const part = Object.fromEntries(utcFormat.formatToParts(new Date(iso)).map(({ type, value }) => [type, value]));
  return `${part.weekday} ${part.day} ${part.month} ${part.year}, ${part.hour}:${part.minute} UTC`;
}

function folderView(folder) {
  const rollup = rollupOf(folder.lines);
  return { name: folder.name, open: rollup.status !== "passed", rollup, lines: folder.lines };
}

// A folder's worst status, and how many of its lines have it.
function rollupOf(lines) {
  const failed = lines.filter((line) => line.status === "failed").length;
  if (failed) return { status: "failed", count: failed, of: lines.length };
  return { status: "passed", count: lines.length, of: lines.length };
}
