---
name: run-pipeline
description: Run the whole feature pipeline end to end in one session — /new-feature → /design-feature → /implement → /finish-feature — still asking the user every grilling question, but judging at each gate whether the outcome needs the user's approval or can proceed on its own. Use when the user wants a backlog item (or a new idea) taken from spec to merged without kicking off each stage by hand.
argument-hint: <backlog ID | spec/design file | new idea in a sentence>
model: opus
---

Chain the four pipeline stages in one session. Each stage still runs **its own skill, in full** — preflight, grilling, artefacts, embedded reviews, completion report — so this skill adds only two things: **sequencing** and a **gate judgement**. It never shortens a stage, and nothing below overrides a stage's hard rules (TDD, one commit per slice, one full sweep, never a horizontal split).

## 0. Find the starting point

From the argument:

- a **new idea** (no canonical ID) → run `/add-backlog-item` first, then start at spec;
- a **backlog ID** with no spec yet → start at spec;
- `specs/<id>-<slug>.md` that's approved, no design doc → start at design;
- `specs/<id>-<slug>-design.md` → start at implement; if its `## Slices` / `## Resume` notes show work in progress, resume from the Resume note;
- slices all closed and a demo pack exists → start at finish.

Say in one line where you're starting and why. If the state is ambiguous (e.g. a design doc but an unapproved spec), ask.

## 1. Run each stage

For each stage from the starting point: invoke its skill with the `Skill` tool and follow it exactly, then apply § 2 at its gate, then move straight to the next stage.

- **Run stages inline, never as subagents.** `/implement`'s verified RED is temporal evidence, and every stage has to be able to stop and talk to the user; a subagent can do neither. The stages' own permitted delegations (review subagents, `Explore`, demo-pack capture) are unchanged.
- **Grilling questions always go to the user.** `/new-feature` § 4 and `/design-feature` § 0 are interviews — ask every round and wait for the answers. Never answer a grilling question yourself, even with a strong recommendation. The same holds for any other question a stage tells you to ask (filling a `TBD` in `docs/PIPELINE.md`, offering a design or sketch waiver, pre-existing test failures).
- **Hand off through the artefact, not your memory.** Where a stage would offer `/clear`, don't — instead start the next stage by re-reading the artefact it is handed (spec, then design doc), exactly as a fresh context would. That keeps the artefacts self-contained and makes an autocompact mid-run survivable. `/implement`'s Resume note discipline still applies at every slice boundary.
- **Emit each stage's completion report** as the stage skill specifies, but replace its `Next →` line with `Next → continuing to /<skill>` (or `— waiting on you` when § 2 stops).

## 2. The gate judgement

At every gate a stage defines, build the decision sheet the stage skill describes — then decide whether it needs the user. **When unsure, stop.** A wrongly stopped gate costs one message; a wrongly passed one costs a re-slice or a rework after merge.

**Stop and wait for the user** if any of these holds:

- a decision on the sheet the user **hasn't already settled** during grilling, where a reasonable person could want the other option — scope, a rule's behaviour, who it's for, the chosen basis when the candidates are close, a new UI pattern or a departure from existing screens;
- the stage proposes a **change to what the user asked for** — a split into a new backlog item, a non-goal that excludes something the backlog entry mentions, a simplification lever worth taking, a requirement relaxed;
- it would **overturn a recorded decision** in `docs/DECISIONS.md`, or contradict an area doc;
- any review finding is **🔴 or 🟠**, or any finding whose fix would change visible behaviour or scope;
- the **UI sketch** introduces a new screen or re-lays-out an existing one, or the **demo pack** came out materially different from the approved sketch (or there was no sketch and the change is user-visible);
- a stage's own hard stops fire: `/implement`'s **size alarm** or a **design-invalidating correction**, a **red full sweep**, or **pre-existing failures** at finish;
- the step is **irreversible or outward-facing** beyond what the user has already authorised — the commit, merge and push in `/finish-feature` are authorised by `CLAUDE.md`; anything else is not.

**Otherwise proceed on your own** — every point on the sheet is either already answered by the user, a direct consequence of those answers, or low-stakes and cheap to reverse later; and any findings are 🟡/🔵 that you can resolve without changing behaviour (fix if trivial and structural, else `/add-backlog-item`).

Either way, **show the sheet**. On a stop, present it exactly as the stage skill specifies and wait. On a pass, print a compact version headed `Gate auto-passed — <stage>`, one line per point with your ruling, and one line on why none of it needed the user — so they can still object, and you act on the objection if they do. Never pass a gate silently.

**Record auto-passed rulings in the artefact** where the stage records gate outcomes — the spec, or the design doc's "questions the gate ruled on" — each marked `(auto)`, so `/finish-feature` carries them into `DECISIONS.md` like any other ruling.

This judgement is the only thing that changes about the gates: what each sheet contains, when artefacts are edited (once, at gate close), and how findings are triaged are still the stage's rules.

## 3. Stopping mid-run

Stop the run — not just the gate — and report where things stand when:

- the user says to stop, or redirects to a different item;
- a stage can't proceed without something outside this session (credentials, a device, an unchosen stack);
- the spec or design gate splits the feature and the user wants to take a different part first.

The artefacts plus `/implement`'s Resume note are the resume point; re-invoking `/run-pipeline` with the latest artefact picks up from § 0.

## 4. Final report

After `/finish-feature`'s own report, close with one line per stage — what it produced and whether its gate **stopped** or **auto-passed** — then the stage's standard fields:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ /run-pipeline — <id> <slug> specced, designed, built and merged
Pipeline: spec ✓ · design ✓ · implement ✓ · finish ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Gates          • spec <stopped|auto> · design <stopped|auto> · demo pack <stopped|auto> · finish <stopped|auto>
Did            • N slices committed; one full sweep green; definitions + FEATURES updated; merged <sha>
Artefacts      • docs/definitions/<area>.md, FEATURES.md, DECISIONS.md (edited); demo-pack Artifact URL
Review         • spec · design · whole-change: <one-phrase verdict each>
Next → pipeline complete   (next: /run-pipeline <backlog ID>)
```
