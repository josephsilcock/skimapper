---
name: ux-iterate
description: Rapid UX/design experimentation on a substantially-complete feature — TDD suspended, fast look-and-feel loop with the user, then a mandatory hardening pass to restore code quality and test coverage. Use when the user wants to experiment with design changes before declaring the feature done.
---

A deliberate mode switch, not a lapse. The feature works; what's unsettled is how it looks and feels, and that is settled by diagnosing the real problem and then *seeing* the agreed candidates rendered, not by writing tests for a design that will change in ten minutes. So `/implement`'s test-first rules are **explicitly suspended** for the duration of the loop — and the licence is paid for by a hardening pass that is never skipped.

**Hard rules — the loop's licence depends on them:**

1. **Checkpoint before anything moves.** The loop starts from a committed, recoverable state. If the tree is dirty, commit or stash first — an experiment you can't revert isn't rapid, it's reckless.
2. **Presentation scope only.** Layout, styling, copy, interaction feel, component structure. A change that alters a business rule, an API contract, or persisted data **ends the loop**: flag it, and either take it back through the pipeline or park it via `/add-backlog-item`. Rules in the design's single-home register are load-bearing; the loop never touches them.
3. **Every shortcut goes in the debt ledger, the moment it's taken.** A test now failing or newly missing, a hack, a hard-coded value, a dead experiment left in place — one line each, kept in the working notes. Debt that isn't written down is debt that survives the hardening pass.
4. **The hardening pass is part of this skill, not a follow-up.** The skill is not done until the ledger is empty and the relevant tests are green. "We'll tidy it later" is the specific failure this rule exists to prevent — later never has the context this session has.
5. **The licence dies with the loop.** Rapid mode never leaks into the next task; the moment the user is happy with the design, normal rules are back.
6. **Diagnose, then discuss, then prototype.** Building alternatives is never how the problem gets located — see the section below.

Everything else — how big an experiment, whether to show two variants side by side, when to screenshot versus just hot-reload — is judgement.

## Entry

- Confirm the precondition: the feature is substantially complete (behaviour built, its tests passing as of the checkpoint). If the feature is still mid-build, say so — this skill isn't a way to skip `/implement`.
- Make the **checkpoint commit** (or verify the tree is clean). Note its sha; it's the revert point for the whole session.
- Say out loud that rapid mode is on and which rules are suspended, so the mode switch is visible in the transcript.
- If the feature had an approved UI sketch (`/design-feature` § 2a), re-read it. The loop is then for what only shows up once it's real — density with actual data, interaction feel, the state nobody predicted — not for relitigating a layout already ruled on. Reopening one of those is allowed, but say that's what you're doing: it's a design decision changing, and it goes into `../../../docs/DECISIONS.md` at finish.

## Diagnose before you prototype

**Prototyping is how a chosen direction gets evaluated, never how the problem gets identified.** The failure this section exists to prevent: naming two or three places the problem *might* be, then immediately building alternatives for all of them. That spends the loop exploring guesses, and the variants that come back argue about the wrong thing.

So each time the user raises a complaint — at entry and again mid-loop — take the time to do this first, and say what you found before touching anything:

1. **Look at the actual thing.** Screenshot the current state and read the markup and styles that produce it. The complaint points at a symptom ("this feels cramped", "I don't like the header"); the cause is somewhere specific, and it is usually one thing, not three.
2. **Name the cause, singular, and say why it produces the symptom** — the spacing scale is inconsistent so the eye finds no rhythm; the two panes compete because neither is dominant; the copy is the same weight as the label so nothing anchors the block. If you genuinely can't tell, say that plainly and ask the user what bothers them about it, rather than covering the uncertainty with a spread of variants.
3. **Confirm the diagnosis with the user before proposing fixes.** A wrong diagnosis makes every alternative below it wasted work, and the user can usually correct it in one sentence.

Then **discuss the alternatives in words** — two or three, each with what it changes, what it costs, and which one you'd pick and why. Recommend; don't just enumerate. The user chooses what gets built. **Only then** does the loop below start, and it builds the agreed candidates — not the full spread.

Discussion is cheap and prototyping isn't: a paragraph the user can reject in ten seconds beats three rendered variants they have to sit through.

## The loop

Change → show → react, as tight as the stack allows — entered with a confirmed diagnosis and an agreed candidate or two, never as the way to find them:

- Run the app via the `run` skill and keep it up — hot reload is the loop's engine. Show each iteration as the user will see it: a screenshot per meaningful variant, or just "reload and look" when the user is driving the browser themselves.
- **No tests are written or fixed in the loop.** If an existing test breaks because the UI it asserted on changed, add it to the ledger and move on — fixing it now means fixing it again after the next variant.
- Commit **experiment checkpoints** liberally with a `wip(ux):` prefix — cheap savepoints so any variant can be recovered or two candidates diffed. These are scaffolding, not slices; they'll be squashed at the end.
- Rendered variants are for **deciding between candidates already agreed above**, where seeing beats describing — they are not a substitute for the diagnosis. If a new complaint surfaces mid-loop, go back to *Diagnose before you prototype* for it rather than adding another variant on a hunch. If genuine visual-design judgement is needed (aesthetic direction, typography), load the `frontend-design` skill if it's available.
- Watch the scope boundary (hard rule 2) on every change, not just the obvious ones — "just make the list also show X" often smuggles in a data or rule change.

## Hardening — when the user says they're happy

Now the debt is repaid, in this order:

1. **Sweep the experiments.** Delete dead variants, orphaned styles/components, hard-coded values, and anything the losing candidates left behind. The surviving code should read as if it were written deliberately.
2. **Refactor to the normal bar** — `/implement`'s REFACTOR standard and the project's own (`../../../docs/CONVENTIONS.md` § Method altitude, § Comments). Rapid code is allowed to be rough *during* the loop precisely because this step exists.
3. **Restore test coverage.** Fix every test the ledger says broke; write tests for behaviour that genuinely changed (not for styling — test what the project's conventions say is test-worthy at each layer). Tests are written against the *settled* design, which is why deferring them was correct.
4. **Run the feature-scoped test layers** — fast tests plus the feature's slow layers (the feature-scoped commands in `../../../docs/PIPELINE.md`), green before proceeding. Not a full sweep — that stays `/finish-feature`'s job.
5. **Empty the ledger.** Walk it line by line; every entry is either repaid or explicitly converted to a backlog item with the user's agreement. An entry that just disappears is the failure mode.
6. **Squash the `wip(ux):` checkpoints** into one or a few coherent commits with descriptive messages and the co-author trailer. Unlike `/implement`'s slice commits, these carry no review value — the experiments' history is noise.

## Report

End with the standard completion report. This skill is a detour, not a pipeline station — say where it re-enters:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ /ux-iterate — design settled, debt repaid
Pipeline: detour complete — re-enters at <implement | finish>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Did            • N iterations from checkpoint <sha>; hardening: sweep, refactor, tests restored, feature-scoped layers green
Artefacts      • <key files>; M commits (wip checkpoints squashed)
Review         • none here — covered by /finish-feature's whole-change pass
Gate           • Confirm the settled design is the one to keep
Next → /finish-feature specs/<id>-<slug>-design.md   (or back to /implement specs/<id>-<slug>-design.md if behaviour work remains)
```
