---
name: run-pipeline
description: Run the whole feature pipeline end to end — /new-feature → /design-feature → /implement → /finish-feature — each stage in its own fresh-context subagent, with this session as a thin coordinator that relays every grilling question to the user and judges at each gate whether the outcome needs the user's approval. Use when the user wants a backlog item (or a new idea) taken from spec to merged without kicking off each stage by hand.
argument-hint: <backlog ID | spec/design file | new idea in a sentence>
model: opus
---

This session is the **coordinator**. Each pipeline stage runs in its own **fresh-context subagent**, which follows that stage's skill in full — preflight, grilling, artefacts, embedded reviews, completion report. The coordinator does four things only: **start** each stage, **relay** between it and the user, **judge** its gates, and **hand off** through the artefact it produced. Nothing here shortens a stage or overrides its hard rules (TDD, one commit per slice, one full sweep, never a horizontal split).

Keep the coordinator thin. Don't read the codebase, edit artefacts, or run tests here — that's the stages' job, and every file the coordinator reads stays in its context for the rest of the run. Read only what a gate judgement or an acceptance check below needs.

## 0. Find the starting point

From the argument:

- a **new idea** (no canonical ID) → a stage agent runs `/add-backlog-item` first, then start at spec;
- a **backlog ID** with no spec yet → start at spec;
- `specs/<id>-<slug>.md` that's approved, no design doc → start at design;
- `specs/<id>-<slug>-design.md` → start at implement; if its `## Slices` / `## Resume` notes show work in progress, the implement agent resumes from the Resume note;
- slices all closed and a demo pack exists → start at finish.

Say in one line where you're starting and why. If the state is ambiguous (e.g. a design doc but an unapproved spec), ask.

## 1. Start a stage

Spawn one `general-purpose` agent per stage with the `Agent` tool — `model: opus` for spec, design and implement, `sonnet` for finish (matching each skill's own frontmatter). Its prompt contains:

1. the stage: *"Run the `<skill>` stage of this project's feature pipeline. Read `.claude/skills/<skill>/SKILL.md` and follow it exactly — it is your whole procedure. Also read `CLAUDE.md`."*;
2. its input: the backlog ID, or the artefact file the previous stage produced — **the file, never a summary of it**; the artefact is the hand-off, as it would be after `/clear`;
3. for `/implement`: *"You are running under `/run-pipeline`: § Evidence log applies."*;
4. the **handback protocol** below, verbatim.

> **Handback protocol.** You are a subagent: you cannot talk to the user, and you may not be able to spawn agents. Wherever your skill says to ask the user, stop at a gate, spawn a subagent, or stop for any other reason, **end your turn** with exactly one handback, headed by its keyword on its own line. You will be continued with the reply; carry on from where you stopped.
>
> - `QUESTIONS` — a grilling round or any other question for the user, written in full exactly as you'd ask it (numbered, each with your recommendation and the consequence of the alternative). The user will see it verbatim.
> - `GATE` — the decision sheet exactly as your skill specifies it, context summary first. Don't edit the artefact for gate outcomes until the reply arrives; then edit it once, as your skill says.
> - `DELEGATE` — the full brief for a subagent your skill tells you to spawn (a review, the demo-pack capture), verbatim and self-contained, plus which agent type. The reply is that subagent's result.
> - `STOP` — a hard stop your skill names (size alarm, design-invalidating correction, red sweep, pre-existing failures, a blocker outside this session), with the situation and your recommendation.
> - `DONE` — your skill's completion report. Only when the stage is finished and its gate has closed.
>
> Never answer your own questions or rule on your own gate. Never end your turn without a handback.

## 2. Relay

When a stage agent returns, act on its handback, then continue **the same agent** with `SendMessage` (load it via `ToolSearch` if it's deferred) — it keeps its context, so the reply needs only the new information.

- `QUESTIONS` → show them to the user **verbatim** and wait. Never answer them yourself, and never trim the recommendations or alternatives. Send back the user's answers as given.
- `GATE` → apply § 3.
- `DELEGATE` → spawn the briefed agent as specified (it gets a fresh context too, as the stage skills intend), then send its result back unedited.
- `STOP` → present it to the user and wait; send back their ruling. If the user wants to stop the run, see § 5.
- `DONE` → show the completion report, run the stage's acceptance check (§ 4), then start the next stage (§ 1) with the artefact the report names. Replace the report's `Next →` line with `Next → continuing to /<skill>`.

The user can also interject at any time between handbacks; pass what they say to the running stage.

## 3. The gate judgement

At every `GATE`, decide whether the sheet needs the user. The coordinator relayed every question and answer, so it knows what the user has already settled; the stage agent wrote the artefact and must not rule on it. **When unsure, stop.** A wrongly stopped gate costs one message; a wrongly passed one costs a re-slice or a rework after merge.

**Stop and wait for the user** if any of these holds:

- a decision on the sheet the user **hasn't already settled** in the relayed Q&A, where a reasonable person could want the other option — scope, a rule's behaviour, who it's for, the chosen basis when the candidates are close, a new UI pattern or a departure from existing screens;
- the stage proposes a **change to what the user asked for** — a split into a new backlog item, a non-goal that excludes something the backlog entry mentions, a simplification lever worth taking, a requirement relaxed;
- it would **overturn a recorded decision** in `docs/DECISIONS.md`, or contradict an area doc;
- any review finding is **🔴 or 🟠**, or any finding whose fix would change visible behaviour or scope;
- the **UI sketch** introduces a new screen or re-lays-out an existing one, or the **demo pack** came out materially different from the approved sketch (or there was no sketch and the change is user-visible);
- the step is **irreversible or outward-facing** beyond what the user has already authorised — the commit, merge and push in `/finish-feature` are authorised by `CLAUDE.md`; anything else is not.

**Otherwise proceed on your own** — every point on the sheet is either already answered by the user, a direct consequence of those answers, or low-stakes and cheap to reverse later; and any findings are 🟡/🔵 that can be resolved without changing behaviour (fix if trivial and structural, else `/add-backlog-item`).

Either way, **show the sheet**. On a stop, present it to the user as the stage produced it and wait, then send their ruling back. On a pass, print a compact version headed `Gate auto-passed — <stage>`, one line per point with your ruling and one line on why none of it needed the user, then send the rulings back marked `(auto)` — the stage records them where it records gate outcomes (the spec, or the design doc's "questions the gate ruled on"), so `/finish-feature` carries them into `DECISIONS.md`. If the user objects to an auto-passed ruling, reopen it with the stage if it's still running, or with a fresh agent for that stage if not. Never pass a gate silently.

What each sheet contains, when artefacts are edited, and how findings are triaged are still the stage's rules; only the approver changes.

## 4. Accept a stage

On `DONE`, check before moving on — cheaply, from the files, not by re-doing the stage:

- **spec / design**: the artefact named in the report exists and the gate's rulings are recorded in it.
- **implement**: every slice in the design doc's `## Slices` is closed with a commit (`git log`), and each has an evidence log under `<results-dir>/tdd/<ID>/` showing a RED failure that is an assertion failing for the absent behaviour — not a compile error or a pass — before its GREEN, plus a REFACTOR line. A missing or doubtful log goes back to the implement agent; it isn't waved through. The demo-pack Artifact URL is in the report.
- **finish**: the sweep is green per the results dir, and the merge is on the trunk.

## 5. Stopping mid-run

Stop the run and report where things stand when the user says to stop or redirects, a stage needs something outside this session (credentials, a device, an unchosen stack), or a gate splits the feature and the user wants to take a different part first. The artefacts plus `/implement`'s Resume note and evidence logs are the resume point; `/run-pipeline <latest artefact>` picks up from § 0.

## 6. Final report

After `/finish-feature`'s `DONE`, close with:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ /run-pipeline — <id> <slug> specced, designed, built and merged
Pipeline: spec ✓ · design ✓ · implement ✓ · finish ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Gates          • spec <stopped|auto> · design <stopped|auto> · demo pack <stopped|auto> · finish <stopped|auto>
Did            • N slices committed (evidence logs checked); one full sweep green; definitions + FEATURES updated; merged <sha>
Artefacts      • docs/definitions/<area>.md, FEATURES.md, DECISIONS.md (edited); <results-dir>/tdd/<ID>/; demo-pack Artifact URL
Review         • spec · design · whole-change: <one-phrase verdict each>
Next → pipeline complete   (next: /run-pipeline <backlog ID>)
```
