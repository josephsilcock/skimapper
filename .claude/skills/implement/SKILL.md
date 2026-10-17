---
name: implement
description: Build an approved design in vertical slices, test-first — one test at a time with verified RED, GREEN, then REFACTOR, committing each slice. Use after /design-feature is approved; hand off to /finish-feature.
model: opus
---

Build the approved design **test-first**, in **vertical slices**. This skill owns both how we slice and how we do TDD; the design gave you decisions, seams and guiding principles, not a plan of the code — the code is discovered here.

Two kinds of instruction below, deliberately distinguished — the fragile steps are prescribed, the rest is yours:

**Hard rules — never traded away, whatever the time pressure:**

1. **Verified RED before implementation.** One failing test, run, failure reported, and confirmed to fail *because the behaviour is absent*.
2. **One test at a time.** Never batch-write tests then batch-write code.
3. **Every slice is vertical**, and every behaviour has an outer test at the layer the design's test strategy names.
4. **REFACTOR happens.** Every cycle, or an explicit statement that nothing needed it.
5. **A rule from the single-home register is called, never restated.**
6. **No full suite runs here.** Fast tests per cycle, feature-scoped slow layers per slice.
7. **One commit per slice.** A closed slice is committed before the next one starts — never batched into one commit at the end.

Everything else — how thin to make a slice, what order to build them, when the design needs amending — is **judgement**. The seven rules above are not: they are not traded against progress, and "I'll do it at the end" is the specific failure they exist to prevent.

Precondition: the design doc's decisions + guiding principles are approved. If there's no design doc (trivial slice, waived), work straight from the spec's Gherkin ACs.

Start by re-reading the design's **Reviewer summary** — its guiding principles are the bar every slice is held to — and its **single-home register**, which tells you where each business rule lives and every path that must consume it.

For a user-visible feature, open the design's **UI sketch** (`specs/<id>-<slug>-ui.html`) too — the approved layout, hierarchy and states are settled input, not a suggestion, and building to them is what stops the tidy-up pass at the end. Reach the agreed look with whatever markup and components the codebase wants; the sketch fixes the design, not the implementation. If a slice can't honour it — the real data doesn't fit, or the pattern fights an existing component — that's a decision, not a quiet substitution: say what you changed and why, in the running decisions section, and show the user at the demo pack.

## Slices

A slice is **one thin end-to-end behaviour**: database → API → UI → outer test, all of it, for one narrow case. Not a layer. "The backend for feature X" is never a slice, because it can't be demonstrated and its outer test can't exist yet.

Every slice MUST pass the **demo test** (`/new-feature` § 5) before you start it: state it as *"<who> does <X>, and sees <Y>"* — or, for genuinely surface-less work, *"<what state> changes, and <what integration test> proves it"*, justified not assumed. Write the sentence into the task list as the slice's name. A slice whose sentence won't write is half a slice; re-cut it.

Size them so each is **easy to review and fast to build** — roughly one commit — but no smaller: a slice that adds an iteration without adding a demonstrable behaviour is waste. Judgement, not a line count.

The first slice should be the **thinnest path that proves the seams** — a walking skeleton through the new code, hard-coding whatever isn't yet needed — so a wrong shape surfaces immediately rather than at sign-off. Then thicken: each later slice adds one behaviour, one edge case, one rule.

**Backend-only slices are legitimate but must be declared.** A cache, a background job, or a migration may have no user-visible surface; per the design's test strategy its outer test is an **integration test against the real database** instead of E2E. Say which it is. What's not allowed is a slice with no outer test at all.

Track the slices somewhere **visible and durable**: the built-in task/todo list tool if this build has one; otherwise a `## Slices` checklist at the foot of the design doc (checkbox per slice, its demo-test sentence as the name). Either way, **keep the statuses live** — mark a slice in-progress when its first RED is written, and done only when its commit lands. This is the user's progress view and the resume point after compaction, so a stale status is a wrong report. The design named the first two to four; **you own the rest** — append slices as you discover them, and re-order when what you learn says to. It's fine to enumerate the *test list* for a slice up front from the ACs — but implement them **one at a time**, never batch-write tests then batch-write code (that collapses RED/GREEN and makes the green bar prove nothing).

**Size alarm.** Past roughly **8 slices**, or when the slice list keeps growing faster than you close it, stop and tell the user: the feature is bigger than the spec claimed. Propose finishing the coherent part and splitting the remainder into a new backlog item via `/add-backlog-item`. This is the pipeline's slice-size signal, and it lives here because only here are the slices real.

## The loop — one test at a time, inside a slice

For each behaviour in the slice, run the full cycle and **show the evidence at each transition** — the run output is what proves the cycle happened, the same way passing layers prove sign-off:

1. **RED — write one failing test.** Use the project's shared test builders/fixtures rather than hand-rolling setup. Then **run the fast tests** and **report the actual failure**. Confirm it fails *for the right reason* (the asserted behaviour is absent) — not a compile error and not an immediate pass (a false RED proves nothing). Verified RED is mandatory before writing implementation, and it is the one rule here with no judgement attached.
2. **GREEN — minimal implementation** to make that one test pass. Run the fast tests; confirm green. Don't build ahead of the test — and in particular don't add the retry, the fallback, or the defensive branch the test didn't ask for. Per the design's **failure posture**, an unlikely failure fails fast, safe and visibly; if you think a case genuinely needs more than that, it needs a test, which means it needs to be a behaviour, which means say so rather than quietly hardening the code.
3. **REFACTOR — improve, tests staying green.** This step is not optional. With the test green, improve names and structure to the bar below — and to the project's own stated bar if it has one (typically `../../../docs/CONVENTIONS.md` § Comments, § Method altitude & narrative flow):
    - orchestrators read as a narrative of named steps at one altitude; isolate irreducible complexity behind an intention-revealing call rather than inlining it;
    - extract when you see the smells — section-comment headers, three-plus collections threaded between phases, an entry-point method that won't fit on a screen, the same shape rebuilt at multiple call sites;
    - a rule from the design's single-home register must be **called**, never restated — if you've just written a second copy of one, that's the extraction;
    - comments only for the unfamiliar reader (a non-obvious *why*); prefer a clearer name or a small extraction over a comment; don't narrate spec decisions.
      Re-run the fast tests; confirm still green.

Only fast tests run inside this loop. Then the next behaviour.

## Closing a slice

When the slice's behaviours are all green, before moving on:

1. **Run its slow layers, feature-scoped** — the real-database integration tests and, for a user-visible slice, its own E2E spec, through the feature-scoped slow-test and E2E commands. Scoped to this feature, never the whole suite: the point is to prove the slice is genuinely end-to-end while it's still cheap to fix, not to run a sweep.
2. **Commit the slice** — now, before starting the next one, with a descriptive message and the co-author trailer. Hard rule 7. This is not a bookkeeping step: the commit boundary is what makes the slice a slice. Uncommitted slices silently merge into one undifferentiated change, which destroys the reviewability the whole scheme is for, removes the only evidence that the work *was* sliced, and leaves nothing to fall back to when a later slice goes wrong. If you notice you've closed two slices without committing, commit them separately now — reconstruct the boundary rather than papering over it — and say so.

**Never run a full suite here** — the single full sweep is `/finish-feature`'s job, after all code churn (including review fixes) has landed.

3. **Update the `## Resume` note.** Every slice boundary, no exceptions — a slice boundary is the only clean checkpoint in this stage, and this note is what makes a context reset survivable whenever it lands, whether that's the user's `/clear` or the harness compacting while nobody is watching. Write it at the foot of the design doc, replacing the previous one: slices closed, the next slice's demo-test sentence, any seam or signature that moved, and anything learned that isn't yet in the register or the decisions section. It is cheap; keeping it current is not negotiable, because you cannot predict which boundary is the last one before the reset.

   **You cannot see your own context utilisation** — no tool reports it, and the token figures in your environment are a session budget, not window fill. So don't schedule the reset off a number you're guessing at, and don't ask the user to check `/context` if they may not be there. Judge by what you *can* observe: how much exploration the recent slices took, whether you're re-reading files you already read, whether your recall of earlier slices has gone vague. On those signals, offer `/clear` here and nowhere else, saying what to re-read on the other side — the design doc (Reviewer summary, single-home register, decisions, the Resume note) and the task list.

   **Don't block on the offer when the session may be unattended.** Absent a reason to stop, keep building: with the note current, an autocompact costs a re-read, not the feature. Only the size alarm and a design-invalidating correction are worth interrupting for.

   **Don't delegate the slice loop to a subagent instead.** Verified RED is temporal — nothing in the finished commit proves the test failed first — so a subagent's report replaces the evidence rules 1, 2 and 4 exist to produce with a claim that they happened; and the loop has to be able to stop and talk to the user (design wrong, size alarm, a case that wants to be a behaviour), which a subagent can't. `/clear` buys the same fresh context with the evidence intact. The one exception is `/run-pipeline`, which runs this whole stage as a single subagent: there the evidence is **written, not reported** (§ Evidence log), and every stop goes back to the coordinator as a handback rather than being skipped. Delegating *inside* a slice is fine where the output is an artefact rather than a claim about process: `Explore` for bounded "where does X live" searches, and the demo-pack capture below.

Follow the project's conventions for the layer you're in — its `../../../CLAUDE.md` and `docs/CONVENTIONS.md` are authoritative on endpoint registration, error/result handling, transaction boundaries, state-change routing, query/mutation patterns, test tagging, and shared wire constants. Where the design's guiding principles and a general convention disagree, the design wins for this feature; say so rather than silently picking.

## Evidence log (when run as a subagent)

Under `/run-pipeline` the user never sees this session, so the TDD evidence has to exist as an artefact. For each slice, write `<results-dir>/tdd/<ID>/slice-NN-<short-name>.md`, appending **as each transition happens** — never reconstructed afterwards:

- the slice's demo-test sentence as the heading;
- per behaviour: the test's name, the **RED** run's command and failure output (trimmed to the failing assertion and its message), the **GREEN** run's pass line, and the **REFACTOR** line — what changed, or "nothing needed", plus the re-run's pass line;
- at slice close: the feature-scoped slow-layer and E2E pass lines, and the commit SHA.

A RED entry whose output is a compile error, a missing-symbol error, or a pass is not verified RED — fix the test and re-run before writing implementation. The coordinator checks these logs before accepting the stage, and a slice without one counts as not closed.

## When the design turns out to be wrong

Expected, not a failure — a shallow design trades detail for the freedom to learn. If a guiding principle or a seam proves wrong:

- a **local** correction (a different signature, an extra column, a reordered slice) is yours to make; just make it;
- a slice that needs a **concept outside the agreed basis** — a new service, table, or type the design's § 2 didn't name — is never local, however small the diff. The additive path is always available and always the lowest-risk way to a green test, which is exactly why the basis was agreed first. Stop and either find how the behaviour falls out of the existing concepts, or treat it as the next bullet;
- a correction that **invalidates a design decision** stops the loop: amend the design doc's Reviewer summary in place, tell the user what changed and why in a couple of sentences, and continue. This is a short amendment, never a new pipeline pass.

Keep a running **"decisions taken during implement"** section at the foot of the design doc: any choice between real alternatives that the design didn't anticipate, one line each with the reasoning. `/finish-feature` merges these into `../../../docs/DECISIONS.md`. Without this, a shallower design just relocates decisions to somewhere nobody reviews.

## Code review — deferred to sign-off

This skill has no embedded review of its own: the code-level adversarial pass is `/finish-feature`'s whole-change review, which runs pre-commit over the accumulated slice commits (its checklist covers correctness, duplication, altitude, and simplification). Don't invoke `/code-review` — it's a built-in the user can only run manually; suggest it to the user mid-loop only if a specific area feels risky enough to review before the slices are done.

## Hand off

Confirm the refactor pass happened across the change (or state plainly that nothing needed it) — `/finish-feature` re-checks this.

Then capture the **demo pack** — the user's first look at the behaviour itself, taken here because changes are still cheap (before the whole-change review and the one full sweep). For a user-visible change: a **screenshot per mainline AC flow** (a short video instead for interaction-heavy flows) — launch the dev app via the `run` skill (on its dev ports, never the E2E ones, so it can't collide with a test run), drive it at a **480px-wide viewport**, and save PNGs to **`<results-dir>/demo/<ID>/`** (the backlog item's canonical ID; for a multi-stage epic keep the one ID folder and prefix filenames with the stage). Have the pack clean up whatever it created — delete its own records through the UI at the end — so the dev database is left as found.

**Leave the app running.** The capture ends with the dev server still up, not shut down — the pack is the user's first look, and the first thing they'll want is to click into it themselves. The subagent must report, alongside each shot, the **URL the shot was taken on** (the deep link, not just the origin), and must not kill the server on its way out. When it returns, `curl` the frontend port yourself to confirm it's still serving; if the subagent's process took it down with it, relaunch via `run` before publishing. Say in the completion report that it's running, on which ports, and that the user stops it when they're done.

**Delegate the capture to a subagent**, handing it that brief verbatim — launch via `run`, the viewport, one shot per mainline AC flow named by its demo-test sentence, the output folder, the URL per shot, clean up its own records, leave the server running. It's a long dump of tool output whose result is self-verifying (the PNGs on disk), so it costs the main window nothing to hand over. Check the folder against the mainline AC list yourself when it returns — and against the approved UI sketch, calling out any screen that came out materially different from what was agreed; build and publish the page here.

**Present the pack as a published Artifact page — that is the default, not the fallback.** Build one HTML page (load `artifact-design` first), one section per mainline AC: its demo-test sentence as the heading, the shot beneath it, embedded as a `data:` URI — the CSP blocks file and remote references, so an unembedded image is a broken image — and beneath that the flow's **live link** into the running app.

Give each link both forms: an `<a target="_blank" rel="noopener">` and the URL as selectable text next to it, because the artifact frame may refuse to open a `localhost` link and a copyable URL always works. Note on the page that the links only resolve while the dev server from this session is up. Publish it with the `Artifact` tool and hand the user the URL; the PNGs on disk stay the source of truth the page is built from. Keep the page's file path stable at `<results-dir>/demo/<ID>/pack.html` so `/finish-feature` redeploys the same URL rather than minting a second one. Fall back to bare paths only when publishing is unavailable or the whole pack is a single shot. Either way, the gate below is the user's **visual acceptance** of the shots. Backend-only change: say so — nothing to show. `/finish-feature` re-verifies AC coverage and recaptures only flows its review fixes visibly change.

Then emit the standard completion report — five fixed fields (**Did · Artefacts · Review · Gate · Next**) in this order, breadcrumb stations `spec · design · implement · finish` (done `✓`, current `[bracketed]`, pending plain), and a **Next** naming exactly one skill **and the artefact file to hand it** — so the user can kick off the next stage with `/<skill> @<file>` after `/clear`, no re-discovery needed:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ /implement — <id> <slug> N vertical slices built test-first, each committed
Pipeline: spec ✓ · design ✓ · [implement] · finish
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Did            • N slices, each RED→GREEN→REFACTOR then feature-scoped slow layers + commit; demo pack captured
Artefacts      • <key files created/edited>; tests; N commits; <results-dir>/demo/<ID>/ + demo-pack Artifact URL; dev server left running on <dev ports> for the pack's live links — stop it when you're done
Review         • deferred to /finish-feature's pre-commit whole-change pass
Gate           • Visual acceptance of the demo pack  <+ any design amendments made>
Next → /finish-feature specs/<id>-<slug>-design.md   whole-change review, demo gap-check, one full sweep, docs, final commit
```

Do **not** declare the feature done here — `/finish-feature` runs the full suite (every layer), updates docs/definitions, and signs off.
