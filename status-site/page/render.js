// Renders the view JSON (lib/view.js) as the page's HTML. Decides nothing: every status comes in the view.

const statusMark = {
  passed: { glyph: "✓", word: "Passed", css: "pass" },
  failed: { glyph: "✗", word: "Failed", css: "fail" },
};

export function renderView(view) {
  return `${headerHtml(view.header)}
<div class="content">
${view.header.published ? "" : unpublishedBanner}
<div class="section-title">Tests by folder</div>
<div class="folders">
${view.folders.map(folderHtml).join("\n")}
</div>
${footHtml(view.header.run)}
</div>`;
}

const footHtml = (run) =>
  `<div class="foot">From <a href="${escapeHtml(run.url)}">sweep run #${run.number}</a>. Only full test runs on main are published; this page refreshes within a few minutes of a new one.</div>`;

function headerHtml(header) {
  return `<header class="head">
<div class="eyebrow">Skimapper automated tests</div>
<h1>Trunk's latest full test run</h1>
<div class="meta">Tested <code>${escapeHtml(header.commit)}</code> on main · ran ${escapeHtml(header.ran)}</div>
</header>`;
}

const unpublishedBanner =
  '<div class="banner"><strong>Not published:</strong> this run is shown on a preview only, and is not on the site.</div>';

function folderHtml(folder) {
  const failed = folder.rollup.status === "failed";
  return `<details class="folder${failed ? " has-fail" : ""}"${folder.open ? " open" : ""}>
<summary><span class="caret">▶</span><span class="fname">${folderName(folder.name)}</span>${rollupHtml(folder.rollup)}</summary>
<ul class="tests">${folder.lines.map(lineHtml).join("")}</ul>
</details>`;
}

function rollupHtml(rollup) {
  if (rollup.status === "passed") return `<span class="fcount">✓ ${rollup.count} of ${rollup.of}</span>`;
  return `<span class="flag fail">✗ ${rollup.count} failed</span><span class="fcount">${rollup.of}</span>`;
}

const folderName = (name) => name.split(" / ").map(escapeHtml).join(" <span>/</span> ");

function lineHtml(line) {
  const mark = statusMark[line.status];
  return `<li><span class="st ${mark.css}">${mark.glyph} ${mark.word}</span><span class="tname">${escapeHtml(line.name)}</span></li>`;
}

const escapeHtml = (text) =>
  String(text).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
