---
name: new-feature
description: Start work on a selected backlog item — preflight checks, full spec, approval gate. Use when a backlog item has been chosen to implement next. (New ideas are captured with /add-backlog-item; no spec until selected.)
model: opus
---

Procedure for starting implementation of a chosen backlog item. Work through in order; stop at the approval gate.

## 1. Preflight

- Check `git status`. Anything must be tidied (committed or discussed) before starting.
- On a branch or worktree, check it isn't behind the **local** trunk (worktrees go stale); merge/rebase first. Spec-only edits are exempt.
- Check `../../../docs/PIPELINE.md`. Any role still `TBD` that this feature will need (fast tests, feature-scoped slow tests and E2E, full sweep, results dir, dev app) gets agreed with the user and filled in now, so `/implement` and `/finish-feature` never start without the commands they run.

## 2. The backlog item

- Work starts from an existing `../../../docs/BACKLOG.md` entry with a canonical ID. If this work doesn't have one yet, run `/add-backlog-item` first.
- Re-read the entry and anything it links (related items, "decided direction" notes, prior specs) — capture notes often record decisions that constrain the design.

## 3. Area-doc review

- Identify and **read** the area doc (s) under `../../../docs/definitions` covering the behaviour being changed — they are the definitive statement of current behaviour and an input to the design, not paperwork.
- Check `../../../docs/DECISIONS.md` for prior decisions touching this area — don't re-litigate a recorded decision without flagging that you're proposing to overturn it (and why).
- Spot-check the area docs against the code as you go. Fix small inaccuracies in the doc as part of the spec commit; surface bigger drift to the user before designing on top of it.
- Check `../../../docs/TIDY_UPS.md` for items applicable to the files/area this feature will touch. Raise any that would change scope at the gate; the rest are picked up by `/design-feature` and folded in during `/implement`.

## 4. Grill before writing

**This is a loop, not a round.** Interview the user until **every decision branch that would change the spec is resolved** — then write. Unresolved branches don't disappear; they resurface at design or mid-implementation as a re-slice, which is the most expensive place to find them.

Each round: a short numbered list of open questions, each with your recommended answer and the consequence of the alternative in a phrase. When the answers open new branches — and they usually do for the first round or two — ask again. Stop when a round produces nothing you'd need to guess at, and say so.

MUST NOT write the spec while a branch you would have to guess at is still open. Guessing here is what produces a spec that reads fine and decomposes badly. If a branch genuinely cannot be resolved yet, name it in the spec as an explicit assumption rather than silently picking.

Scope this to what would change *the spec* — intent, scope, rules, who it's for. Technical branches belong to `/design-feature`, and "how will we build it" questions here are ceremony. If the backlog entry, prior decisions and area docs already leave nothing open, say so in one line and continue.

## 5. Spec — level 1 only (intent, not design)

The spec captures **what and why**, not how. Decomposition, interfaces, and the change plan are the next skill's job (`/design-feature`) — keep them out of here so this artefact stays reviewable at one altitude.

**What a feature is sized to be:** one **deliverable increment** — a single useful, coherent capability the user could be shown and would recognise as a thing that now works. Small enough that `/implement` has a high chance of nailing it in one pass; large enough that we aren't paying for a whole extra pipeline iteration we didn't need. Err towards coherence over smallness: cheap subdivision happens inside `/implement`, as vertical slices, and the slice-size alarm lives there.

### The demo test

The pipeline's one mechanical check on any proposed unit of work — a feature, an epic stage, or a slice. It is used identically here, at `/design-feature`, and at `/implement`:

> **Name the screenshot.** State the unit as a single sentence of the form *"<who> does <X>, and sees <Y>"*. If you cannot write that sentence — because the answer is "nothing yet", "the API returns JSON", or "the table exists" — it is not a unit of work. It is half of one.

Write the sentence out; don't assert that it could be written. Anything layer-shaped fails immediately and visibly, because "the pools API" has no *sees*. The single exception is genuinely surface-less work (a cache, a scheduled job, a migration), which substitutes *"<what observable state> changes, and <what integration test> proves it"* — and which MUST be justified rather than assumed, because it is also the escape hatch a layer-shaped stage will reach for.

This is the same sentence that becomes a demo-pack screenshot at the end of `/implement`. A unit that can't produce one was never signed off.

Write `specs/<id>-<slug>.md` containing:

- **Intent** — the problem and the goal in a sentence or two: what changes for whom, and why it's worth doing. This is where the discussion squarely sits.
- **Acceptance criteria** as Gherkin (`Given / When / Then`) — the **mainline behaviours only**, plus any edge or error case that genuinely changes what gets built (a rule the user would argue about, a state the model has to represent). Exhaustive edge-case enumeration belongs at `/implement`, discovered per slice and captured as tests rather than as spec prose. These ACs become the outer-test list and the demo-pack flows at sign-off, so keep the list short enough that every line is load-bearing.
- **Non-goals / out of scope** — name what this feature deliberately does *not* do. This is the primary scoping tool and the guardrail against scope creep during implementation; never omit it, and never thin it — it is the section the gate leans on hardest.
- **NFR trigger** (one line): any performance / security / data-volume / concurrency / migration implication? If none, say so explicitly — the failure mode is not *noticing* the one feature that has one, not writing too little.
- **Simplification levers** (brief): which requirement(s) look like they drive most of the implementation cost, and any requirements change (relaxation, phasing, different UX, coarser granularity) that would open a materially simpler path — stated with what it gives up, so the user can trade it off at the gate. If nothing stands out, say so explicitly. Requirements are cheapest to change here; this section exists to force the question before design locks them in.
- A brief **UX note** only if there's a user-visible change.

Check against **INVEST** — Independent, Negotiable, Valuable, Estimable, **Small**, Testable. If it fails Testable, or fails Small badly enough that it's really two capabilities, split it (capture the rest via `/add-backlog-item`) before proceeding. Don't split it down to the smallest testable thing: that's `/implement`'s vertical slices, and doing it here buys N spec-and-design gates for one deliverable.

**MUST NOT split along layers.** "The API for X" then "the UI for X" is the anti-pattern this pipeline exists to avoid: a layer-shaped increment cannot be demonstrated, cannot carry an end-to-end outer test, and defers all integration risk to its sibling. If a feature is too big, split it by **behaviour** (fewer cases, a coarser rule, one role instead of three) — never by tier.

**For multi-stage epics**: one parent spec owns the exit criteria (a definition of done) and the stage breakdown; each stage gets its own level-1 detail (a section here) and its own approval before it starts. Prefer stage sections over many files. Scope beyond the exit criteria is `/add-backlog-item`, not a new stage.

**Every stage MUST pass the demo test, and the breakdown MUST show the sentences.** Write the *"<who> does <X>, and sees <Y>"* line under each stage heading in the spec — this is the single highest-risk moment in the pipeline for a horizontal split, because proposing a breakdown is exactly when decomposing by tier feels most natural and most efficient. If a stage's sentence can't be written, the breakdown is wrong; re-cut the stages by behaviour (fewer cases, a coarser rule, one role instead of three, hard-coded where the next stage makes it real) until every stage has one. Two stages named "backend"/"API" and "frontend"/"UI" for the same capability is the specific failure to watch for, and it is never the right answer.

Add the feature to `../../../docs/FEATURES.md` if not already there.

## 6. Adversarial spec review (embedded)

Before the gate, spawn a **clean-context `Explore` subagent** to review the spec adversarially at the spec altitude. Prepend the **pre-implementation review contract** to its prompt verbatim — it is the guardrail against a code-oriented reviewer reporting the expected absence of code as a defect:

> You are reviewing a **design artefact** (a spec or design doc), not code. The implementation does not exist yet — its absence is the expected state and is **never a finding**. Do not report "missing", "not implemented", "no such method/handler/table", "TODO", or "could not find X" as defects. Existing code is available **only as context** to judge whether the artefact fits reality — it is never the subject of the review. Every finding must **anchor to a line in the artefact** (spec/design doc) or a spec AC; a code `file:line` may appear only as *supporting evidence* for a defect in the artefact, never as the finding itself.

Then ask it to actively find:
- **a horizontal split** — apply the demo test to the feature and to *every* epic stage, and report any unit whose *"<who> does <X>, and sees <Y>"* sentence cannot be written, or whose surface-less exemption is asserted rather than justified. Two stages that divide one capability by tier are 🟠 Major. This is the check most worth running: it is the failure this pipeline exists to prevent and the one that keeps recurring;
- INVEST violations — especially not-Testable (ACs too vague to test), or a spec that is really two unrelated capabilities. It should **not** report "could be smaller" on its own: subdivision into vertical slices happens at `/implement`;
- edge/error cases the ACs don't mention **and that would be silently wrong** — a bad value accepted, a stale read served as fresh, a partial write left behind. Report an unhandled case only when failing fast on it would be *invisible* or *irreversible*; at this scale a rare case that surfaces as a clear error is handled, and "you should also handle X" is not a finding;
- a hidden NFR the trigger line waved past;
- a requirement whose cost looks disproportionate to its value — where a small requirements change the spec hasn't considered would open a materially simpler implementation;
- intent that's ambiguous enough to block writing a failing test, or scope that bleeds past the non-goals.

It returns advisory findings (🔴/🟠/🟡/🔵) with reasons. Summarise them in the report's Review line; they are input to the gate, not auto-applied.

## 7. Report & approval gate

**STOP.** A gate is reviewed **in chat, never by reading the artefact.** The decision sheet opens with a **context summary** — a short plain-prose paragraph stating what is being proposed, enough that every decision below can be answered without opening the spec. Never jump straight into the decisions. Then roughly one screen of numbered points: the key scoping decisions and open issues (each with a clear recommendation and the rejected alternative in a phrase), the non-goals, the simplification lever(s), and the review findings needing a ruling. The user answers the whole set in one go — don't drip decisions one at a time, and don't ask for a line-by-line read of the spec.

**Do not present the ACs for approval, and never list them in the sheet.** The gate rules on *intent, scope and tradeoffs*; the ACs are the derived test list, and their correctness is confirmed by the demo pack at the end of `/implement`, where the behaviour is real. Raise an AC individually only when it *is* a decision — a rule the user would plausibly want different.

Hold agreed changes as chat-level deltas and **edit the spec once, when the gate closes** — it is the durable record, complete and self-contained before the next skill starts from a fresh context, but it is never the review medium and is never rewritten per discussion point. If one discussion point forces a rewrite of half the document, that's the slice-size alarm, not a normal revision.

- Deferred findings become `/add-backlog-item` entries.
- After approval, offer `/clear` — the spec is self-contained, so design can start from a fresh context.
- End with the standard completion report — five fixed fields (**Did · Artefacts · Review · Gate · Next**) in this order, breadcrumb stations `spec · design · implement · finish` (done `✓`, current `[bracketed]`, pending plain), and a **Next** naming exactly one skill **and the artefact file to hand it** — so the user can kick off the next stage with `/<skill> @<file>` after `/clear`, no re-discovery needed:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ /new-feature — spec written for <id> <slug>
Pipeline: [spec] · design · implement · finish
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Did            • Intent + N mainline ACs + non-goals; sized as one deliverable increment (rest → F###)
Artefacts      • specs/<id>-<slug>.md (created); FEATURES.md (edited)
Review         • spec skeptic: <verdict + any findings>
Gate           • Respond to the decision sheet (scoping decisions + findings, one set)
Next → /design-feature specs/<id>-<slug>.md   once approved: basis, decisions, seams and risks
```
