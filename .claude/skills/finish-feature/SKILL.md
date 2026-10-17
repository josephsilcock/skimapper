---
name: finish-feature
description: Feature sign-off — whole-change review, demo-pack gap-check, one full test sweep, docs, commit. Use when a feature or epic stage is believed complete and about to be declared done.
model: sonnet
---

Sign-off checklist before declaring a feature complete. Never skip a layer. This is the pipeline's last step (`spec → design → implement → finish`); its embedded review is the whole-change pass, and it runs **before** the full sweep so all code churn lands ahead of the one expensive run.

Commands below are named by role; `../../../docs/PIPELINE.md` maps each to this project's actual command (missing → fill it in with the user first, as `/new-feature` § 1 does).

## 1. Refactor confirmation

- Confirm `/implement`'s **REFACTOR** pass actually happened across the change — a deliberate structural/altitude pass to the bar `/implement` states, plus the project's own if it has one (`../../../docs/CONVENTIONS.md` § Method altitude, § Comments) — or state plainly that nothing needed it. This is a conscious step, not an assumption; if it was skipped under time pressure, do it now before sign-off.

## 2. Embedded review — whole-change (pre-commit)

- Run `/review-last-commit` — it reviews the **whole feature**: `/implement` commits one slice at a time, so the subject is the accumulated range of slice commits plus anything still uncommitted, not the last commit alone. Adversarial, clean-context, read-only, against the project checklist. This is the pipeline's final, cross-cutting review (it catches what only shows up across the whole change); the per-step reviews already covered spec and design in isolation.
- **Present the findings to the user for approval — never apply review fixes unilaterally.** The review output is advisory until the user accepts each finding.
- Accepted 🔴/🟠 items: fix **now**, before the sweep — reviewing here means review fixes never invalidate a completed full run.
- Accepted-but-deferred items: capture via `/add-backlog-item`, or as a short Follow-ups note in the parent epic spec. Never create a separate review/markups tracking file.

## 3. Demo pack — verify coverage

The pack was captured and visually accepted at the end of `/implement`; this step keeps it honest, it doesn't redo it.

- Verify **`<results-dir>/demo/<ID>/`** covers **every mainline AC** — a flow with no shot is a flow nobody signed off. Capture any missing flow now, by `/implement`'s capture rules (the `run` skill on the dev app's ports, a 480px-wide viewport, PNGs into the one ID folder, stage-prefixed filenames for a multi-stage epic, the pack cleaning up its own records, each shot's page URL recorded as a live link on the page, and the dev server left running afterwards — it sits on the dev ports, so it doesn't clash with step 4's E2E sweep).
- Recapture any flow whose **visible behaviour changed under step 2's review fixes**, then **redeploy the same demo-pack Artifact** (same `<results-dir>/demo/<ID>/pack.html` path, so the URL the user already has updates in place) and re-present just those shots for acceptance — the shots the user accepted must match what ships. Most review fixes are structural and change nothing visible; when that's so, say so and move on.
- If this session never started the app (nothing needed recapturing), the pack's live links point at a server that isn't up. Say so when you hand the page back rather than letting the user click into nothing — offer to start it via `run` if they want to poke at the feature before sign-off.
- Backend-only change: say so — nothing to show.

## 4. All test layers — one full sweep, after all churn

- Run the **full sweep** — **exactly one full sweep per feature**, after review fixes and refactoring have landed. The feature-scoped slow-layer runs at each slice close don't count: they prove each slice end-to-end, not that the rest of the suite still passes. Sign-off requires every layer green in this sweep.
- Prefer running it in the background and continuing with step 5 — or even the next item's spec discussion — while it runs; the commit waits for green.
- Read the summary files in the results dir to see failures — don't re-run to find out what failed.
- Pre-existing / unrelated failures: discuss with the user how to approach them. Do not ignore them or silently skip the layer.

## 5. Tidy-ups and docs

- Check `../../../docs/TIDY_UPS.md`: fold applicable items for the files touched into this same piece of work.
- **Apply the design doc's Definition delta** (if design was waived, derive it from the spec's ACs): merge the behaviour **as actually built** into the area doc (s) under `../../../docs/definitions`, deleting superseded text in the same edit — the area doc must never describe both the old and new model.
- **Record noteworthy decisions in `../../../docs/DECISIONS.md`**: any choice between real alternatives with non-obvious rationale (model shape, sync-vs-async, rejected approaches and why). Start from the design doc's Reviewer summary **and its "decisions taken during implement" section** — that section exists because a principle-level design pushes real choices into the build, and this is the step that stops them dying with the design doc. Most features add zero or one entry; don't log routine scoping. Write for a future reader who wants the durable rule and *why*, not the story of this task: capture the decision, its core reasoning, and rejected alternatives — omit the audit/investigation narrative, the specific bug being fixed, and descriptions of existing code that was already fine. If a sentence wouldn't matter to someone reading the rule a year from now, cut it.
- **Delete the spec, design-doc and UI-sketch files** (`specs/<id>-<slug>.md`, `…-design.md` and `…-ui.html`) — behaviour now lives in the area docs, decisions in DECISIONS.md, history in git. (An epic's parent spec survives until the epic's exit criteria are met, then merges and dies the same way.)
- Update `../../../docs/FEATURES.md` status to `done` — status + one-liner only; detail belongs in the area doc.
- Delete any resolved `../../../docs/BACKLOG.md` entries (delete, don't strikethrough). If the backlog has a
  **Next up** queue, pop the item that just landed and top the queue back up to ~5, proposing the
  addition at the gate rather than picking silently.

## 6. Commit

- Commit only once the sweep is green, with a descriptive message and the Claude co-author trailer. The slices are already committed, so this is the sign-off commit — review fixes, tidy-ups and docs. Don't rewrite or squash the slice commits; their sequence is the record that the feature was built test-first.
- In your message to the user, explicitly note the FEATURES.md and definitions updates.
- Merge the branch into the trunk. Push.

## 7. End of an epic

- When the parent spec's exit criteria are met: additionally run `/review-architecture code
  <epic's area>` and triage its findings with the user (fix now, backlog item, or accept). Any finding that
  has recurred across reviews gets a mechanical-ratchet proposal (architecture/convention test) per the
  review skill's priority 9.

## 8. Report

End with the standard completion report — five fixed fields (**Did · Artefacts · Review · Gate · Next**) in this order, breadcrumb stations `spec · design · implement · finish` (done `✓`, current `[bracketed]`, pending plain), and a **Next** naming exactly one skill and the artefact file to hand it (or `— pipeline complete`):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ /finish-feature — <id> <slug> signed off & committed
Pipeline: spec ✓ · design ✓ · implement ✓ · finish ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Did            • Review fixes in; demo pack verified (recaptured <flows/none>); one full sweep green; definitions + FEATURES updated; spec/design/sketch deleted; committed <sha>
Artefacts      • docs/definitions/<area>.md, FEATURES.md, DECISIONS.md (edited); <results-dir>/demo/<ID>/ + demo-pack Artifact URL
Review         • whole-change (pre-commit): <verdict + any findings>
Gate           • Rule on findings + acceptance of any recaptured demo shots
Next → pipeline complete   (next epic stage → /new-feature specs/<epic-id>-<slug>.md, or /new-feature <backlog ID>)
```
