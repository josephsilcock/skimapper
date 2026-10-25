import assert from "node:assert/strict";
import { test } from "node:test";

import { renderView } from "../page/render.js";

const view = {
  kind: "run",
  header: { commit: "e76ac93", ran: "Sat 24 Oct 2026, 14:52 UTC", run: { number: 212, url: "https://github.com/o/r/actions/runs/7" }, published: true },
  folders: [
    { name: "app", open: false, rollup: { status: "passed", count: 2, of: 2 }, lines: [{ name: "a", status: "passed" }, { name: "b", status: "passed" }] },
    {
      name: "app / resorts",
      open: true,
      rollup: { status: "failed", count: 1, of: 2 },
      lines: [{ name: "lists <each> resort", status: "passed" }, { name: "pulls to refresh", status: "failed" }],
    },
  ],
};

const folders = (html) => [...html.matchAll(/<details class="folder([^"]*)"( open)?>([\s\S]*?)<\/details>/g)];
const text = (html) => html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();

test("each folder shows its name and roll-up and holds its tests; one with a failure is open, bordered and badged, listing each test as glyph and word", () => {
  const shown = folders(renderView(view));
  assert.equal(shown.length, 2);
  const [app, resorts] = shown;

  assert.equal(app[2], undefined);
  assert.equal(text(app[3]), "▶ app ✓ 2 of 2 ✓ Passed a ✓ Passed b");
  assert.equal(resorts[1], " has-fail");
  assert.equal(resorts[2], " open");
  assert.equal(text(resorts[3]), "▶ app / resorts ✗ 1 failed 2 ✓ Passed lists &lt;each&gt; resort ✗ Failed pulls to refresh");
});

test("the header names the commit tested and when the sweep ran, and links the run; an unpublished run says so", () => {
  const published = text(renderView(view).match(/<header[\s\S]*?<\/header>/)?.[0] ?? "");
  const unpublished = renderView({ ...view, header: { ...view.header, published: false } });

  assert.equal(published, "Skimapper automated tests Trunk's latest full test run Tested e76ac93 on main · ran Sat 24 Oct 2026, 14:52 UTC");
  assert.match(renderView(view), /From <a href="https:\/\/github.com\/o\/r\/actions\/runs\/7">sweep run #212<\/a>/);
  assert.match(text(unpublished), /Not published: this run is shown on a preview only, and is not on the site/);
  assert.doesNotMatch(text(renderView(view)), /Not published/);
});
