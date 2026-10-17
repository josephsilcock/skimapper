---
name: design-feature
description: Turn an approved spec into a reviewable design — the technical risks, the decisions and guiding principles, the seams, and where each business rule lives. Deliberately not detailed. Use after /new-feature is approved and before /implement.
model: opus
---

Turn an approved level-1 spec into a design that can be reviewed *before* any code. **One design per feature, 1:1 with the spec** — never several designs inside one spec.

The design's job is to answer the **technical and complexity questions**, record the **decisions and guiding principles** that will hold across the whole feature, and name the **seams**. It is explicitly *not* a plan of the code: signatures, exact columns, and the ordered list of files to touch are discovered during `/implement`, test-first. A design that enumerates the code goes stale the moment implementation learns something, and re-planning it is the expensive iteration this pipeline exists to avoid.

Preconditions: the spec (`specs/<id>-<slug>.md`) is approved. Re-read it and the area doc(s) under `../../../docs/definitions` the change touches; check `docs/DECISIONS.md` for prior decisions and `docs/TIDY_UPS.md` for items in the files you'll touch.

The design lives in **`specs/<id>-<slug>-design.md`** and should read in about **one to two pages**. It is a working artefact: at `/finish-feature` its behaviour merges into the area docs, its decisions into `DECISIONS.md`, and the file is deleted — same lifecycle as the spec.

> For a genuinely trivial slice the user may waive the design doc and go straight to `/implement`. Default is to produce it; offer the waiver, don't assume it.

## 0. Grill first

Same loop as `/new-feature` § 4, aimed at the **technical** branches this time: interview until every decision branch that would change the design is resolved, then design. Each round is a short numbered list, each question with your recommended answer and the consequence of the alternative in a phrase; when answers open new branches, ask again. Stop when a round produces nothing you'd have to guess at, and say so.

MUST NOT start designing while a branch you would have to guess at is still open — an unresolved branch here becomes a re-slice mid-implementation.

**The shape is never a judgment call to raise only if it feels contentious.** § 2 always produces competing bases and the gate always rules on them — an agent asked for one design will produce one and defend it, so the search for the compositional shape has to be a required output, not a lens.

---

## The design

Write the doc in this order. Stay at the altitude described; resist dropping into code.

**1. Reviewer summary (mandatory, top of the doc, ≤1 page).** The durable record of what the gate agreed — the whole point of the artefact, since everything else is scaffolding for implementation. It contains exactly:

- the **basis** chosen — the set of concepts the feature rests on, in a sentence — and the rejected candidate basis in a phrase, with why;
- the genuine **decisions** (typically 3–7), each with the rejected alternative and *why*;
- the **guiding principles** this feature will be built to — the rules `/implement` should hold every slice against (e.g. "distances are metres everywhere below the map-rendering boundary", "the route service is the only writer of a route's runs"). These are what replace a detailed plan: state them once, apply them N times;
- **risks / blast radius** in a sentence or two, and the **technical unknowns** — anything that could invalidate the shape, with how implementation will find out early;
- any **spec requirement driving disproportionate complexity**, with the requirements change that would simplify it and what it gives up (or "none") — the design is where cost becomes concrete, so raise this even if the spec's simplification-levers line found nothing;
- what is explicitly **not changing**;
- the **questions the gate ruled on** and their outcomes.

If a decision isn't in the summary, it isn't approved — don't bury choices in the detail sections.

**2. Basis, then decomposition.** Before naming any module, name the **basis**: the small set of concepts (existing and new) the feature rests on, what each one **owns**, and how each acceptance criterion **falls out of composing them**. This is where the design is won or lost, and it is the part an agent driving at a goal skips: the additive path — a new function, a new field, a new service per requirement — always satisfies the spec and always leaves more concepts than the behaviour needs.

**Offer two candidate bases at different granularities** (three if a third is genuinely distinct), each in a short paragraph: its concepts and what each owns; how the ACs fall out; and **what it makes hard** — the AC it strains on, the future change it resists, the existing model it fights. Recommend one and say why in a sentence. Existing concepts count: a basis that extends something already in the codebase with a missing degree of freedom usually beats one that adds a sibling next to it. Where a basis would be materially simpler if a requirement moved, say so — that feeds the simplification-lever bullet in § 1.

Then the **decomposition sketch** of the chosen basis: which modules/services/handlers/components are new or change, and how they collaborate.

> This section describes **structure**, and structure is organised by layer. That is correct here and nowhere else. A module inventory is not a build order: do not let it become one, and do not let its shape leak into § 7's slices. The code is built across these modules in thin behavioural passes, not one module at a time.
Name the **seams** — the boundaries implementation must not blur, and the ones the tests will hang off. Use Mermaid (renders in markdown, diffs in PRs) only where the flow or structure is genuinely non-obvious; never embed images. Keep this to a diagram plus a short paragraph, not a module-by-module inventory.

**2a. UI sketch (any user-visible change).** Draw the screens before anyone builds them. Settling layout, hierarchy and states here costs a redraw; settling them after the slices are green costs a retrofit, which is the inefficiency this section exists to remove.

One self-contained HTML page at **`specs/<id>-<slug>-ui.html`**, published as an Artifact (load `artifact-design`, and `frontend-design` if it's available when the visual direction is genuinely open) and handed to the user as a URL at the gate. It is a **sketch, not a component**: static markup, no wiring, no real data — plausible fake content at realistic length, so the layout is judged against the content it will actually hold.

**Draw the smallest thing that settles the question.** If the change is localised — a panel, a form, a table's row actions, a new section in an existing page — sketch that region, with just enough of its surroundings to place it. A whole screen is for a screen that is new or genuinely re-laid-out. Drawing chrome nobody is changing is wasted work and buries the part under review.

**Two to four sections is the target, not a checklist of states.** Include a state only where it changes the layout *and* the choice is open — a genuinely empty-first feature, an error that has to live somewhere, a wait long enough to need a design. Predictable corner cases and low-impact variants are decided in the slice, not here; if you can say what it looks like in a sentence, write the sentence instead of drawing it. If the sketch is growing past a handful of sections, that's a signal to cut it back, or a signal the feature is two features.

Draw at the 480px viewport the demo pack uses, and note responsive intent in a line of prose rather than drawing every breakpoint.

Match the existing app: read the components and styles of the screens you're touching first and reuse their spacing, type and control idioms, so the sketch is a proposal the codebase can actually honour. Where you deliberately depart from the current pattern, say so and why — that is a decision, and it belongs in the Reviewer summary.

**The sketch is evidence; the summary is the record.** The HTML file dies at `/finish-feature` with the spec and design doc, so any UI choice with consequences — a new pattern, a screen split in two, a control the user rejected and what replaced it — is written into § 1 as a decision in words. "See the sketch" is not a decision.

Skip it for a backend-only change (say so). The user may waive it for a small addition to an existing screen — one field, one button, no layout change — the same way the design doc itself can be waived; offer the waiver, don't assume it.

**3. Single-home register (mandatory).** The one concrete obligation this design carries, because it is the thing that is expensive to discover late. A short table:

| Business rule | Single home | Paths that consume it |
|---|---|---|
| … | … | … |

Every spec'd rule involved in this change gets a row, whether it is new or already exists. Names must be real (a type, a module, a function), and the consuming-paths column must list **every** path — each user-facing flow, backend and frontend, application code and SQL. A rule planned to be re-derived at a call site is a design defect, not an implementation detail. Where an existing rule gains a new consumer, say so: that is the row most likely to hide a call site nobody updates.

**4. Data / schema shape.** New tables, columns, indexes and the migration *strategy* — at the level of "what shape and why", plus anything genuinely risky (backfill of existing rows, a NOT NULL on a populated table, a unique index that could already be violated). Exact DDL, nullability, and cascade choices are implementation detail; the risk is not.

**5. Test strategy.** Organised **per behaviour**, not per layer — the list below names which layer owns a behaviour's outermost test, and is not a list of test-writing phases. For each behaviour this feature delivers, which layer is its **outer test**:

- user-visible behaviour → **E2E**, exercising the UI + API + real database black-box;
- behaviour with no user-visible surface (a cache, a background job, a migration) → **integration test against the real database** as the outer test instead. Name these explicitly rather than letting a slice quietly ship with only unit coverage.

Note which paths need the real database rather than an in-memory provider (optimistic-concurrency tokens, NOT NULL, real transaction semantics) — an in-memory provider won't exercise them, and pretending otherwise is how a concurrency race ships broken.

**5a. Failure posture.** State it in one or two lines, because the default is *not* to handle everything.

At the scale stated in `../../../CLAUDE.md` § Scale, a failure that is unlikely to be hit should **fail fast, fail safe, and fail visibly**, and nothing more. Complex handling is bought with evidence from production, not anticipated. An unhandled case that surfaces as a clear error is a legitimate, and usually correct, design choice; say so explicitly rather than letting it look like an oversight.

Three exceptions, and only three:

- **It can't be seen.** Fail-fast in a request path is free — the user sees the error. In a background job, a scheduled sync, or a migration, a fast failure is a *silent* failure unless something raises it to a human. Those paths must name what surfaces the failure, or they don't get the default.
- **It can't be undone.** Anything that could corrupt or lose data, or leave a side effect half-applied, is handled properly regardless of probability.
- **Authorization.** Never degrades to a default.

Everything else: name it as accepted, and move on.

**6. Definition delta.** Which area doc(s) under `../../../docs/definitions` change and how — what's added, what's superseded and will be deleted at finish.

**7. First slices (indicative, not exhaustive).** Two to four bullets naming the first slices in the order they should be built. **Do not enumerate the whole slice list**; `/implement` owns it and discovers the rest as it goes.

A slice is **one thin end-to-end behaviour** — database through API through UI, all of it, for one narrow case. Never a layer, never a module from § 2, never a phase of the migration. **Each bullet MUST be written as its demo-test sentence** — *"<who> does <X>, and sees <Y>"* (or, for genuinely surface-less work, *"<what state> changes, and <what integration test> proves it"*, justified not assumed). Write the sentences; if one won't write, that bullet is half a slice and the cut is wrong.

The first slice should be the thinnest thing that proves the seams — a walking skeleton through the new path, hard-coding everything not yet needed — so a wrong shape surfaces on day one rather than at sign-off. Later slices thicken it: one behaviour, one case, one rule each. A slice that touches only the parts of § 2 it needs is normal and correct; a slice that completes one of § 2's modules is the anti-pattern.

### Not in this document

MUST NOT contain: full type signatures or method bodies; exact column definitions and nullability; an ordered file-level task checklist; per-file test lists. The § 2a sketch is exempt from the no-code rule *as a drawing* — but it must not become a component plan: no state management, no props, no event wiring, and `/implement` is free to reach the agreed look with different markup. This is the rule this skill will drift back across, because writing the plan feels like progress — but it is `/implement`'s job, done here at the altitude where it is most likely to be wrong, and it is what makes designs need re-planning. If you find yourself writing one of these, stop and ask whether the *decision* behind it belongs in the Reviewer summary instead.

## Slice size

The size alarm has moved to `/implement`, which counts real slices against reality rather than a plan. Design escalates on **coherence**, not length: if the feature turns out to bundle two unrelated changes, or its risks split cleanly into two independent halves, propose the split now. Otherwise carry the whole feature through — an extra whole-pipeline pass is more expensive than a slightly larger implement stage.

The signal that *this document* is wrong is the same one as before, though: if the summary's decision list runs past ~7, or one gate discussion point forces a rewrite of half the doc, the feature is probably two features.

## Embedded reviews — both before the gate

- **Architecture lens**: run `/review-architecture design <this change>` — the **design mode** judges the *planned* shape (is the chosen basis the smallest that carries the ACs, and is a rejected candidate actually the better fit? does each rule have a single planned home? are the named seams coherent? does the decomposition fit the existing model?), reading existing code only as context.
- **Design skeptic**: spawn a **clean-context `Explore` subagent**. Its targets, in priority order: **do § 7's slices pass the demo test** — each stated as *"<who> does <X>, and sees <Y>"*, none of them a layer, a module from § 2, or a migration phase, and any surface-less exemption justified rather than asserted (a layer-shaped first slice is 🟠 Major); **is the basis honest** — do the candidates in § 2 differ in kind rather than in naming, does the recommended one's "what it makes hard" paragraph actually name its weakest AC, and is there an existing concept in the codebase that would carry the feature with one more degree of freedom instead of a new sibling; does the decomposition actually satisfy the spec's intent, or does it satisfy a narrower reading of it; **is the single-home register complete** — every rule listed, every consuming path named (use a referencing-symbols check to find existing call sites; a consumer the register omits is a defect *in the register*); do the stated guiding principles conflict with each other or with a recorded decision in `DECISIONS.md`; does the migration/data shape carry an unstated risk; does the § 2a sketch skip something the gate actually has to rule on, or conversely pad itself with corner cases that belong in a slice, and does any UI choice it makes sit only in the HTML rather than as a decision in § 1; does the test strategy leave a behaviour whose only coverage would be unit tests; and does the **failure posture** hold — specifically, has anything been left to fail fast where the failure would be *invisible* (a background path with nothing raising it to a human) or *irreversible*. Do not report "case X is unhandled" on its own: at this scale that is a choice, and the design says so. Findings anchor to the design doc or a spec AC (🔴/🟠/🟡/🔵), with code file:line as supporting evidence only.

Both run under the **pre-implementation review contract** — prepend it verbatim to the skeptic's prompt:

> You are reviewing a **design artefact** (a spec or design doc), not code. The implementation does not exist yet — its absence is the expected state and is **never a finding**. Do not report "missing", "not implemented", "no such method/handler/table", "TODO", or "could not find X" as defects. Existing code is available **only as context** to judge whether the artefact fits reality — it is never the subject of the review. Every finding must **anchor to a line in the artefact** (spec/design doc) or a spec AC; a code `file:line` may appear only as *supporting evidence* for a defect in the artefact, never as the finding itself.

## The gate

**STOP.** A gate is reviewed **in chat, never by reading the artefact.** The decision sheet opens with a **context summary** — a short plain-prose paragraph stating what is being proposed: the shape of the change and its key features, enough that every decision below can be answered without opening the design doc. Never jump straight into the decisions. Then roughly one screen of numbered points: **the candidate bases, recommended one first, each with what it makes hard** — this is the point most worth the user's attention, so it goes first — the genuine decisions with a clear recommendation each (and the rejected alternative in a phrase), the guiding principles, risks/blast radius and unknowns, the simplification lever(s) (or "none"), what's not changing, anything notable in the single-home register, **the UI sketch's Artifact URL with the two or three layout choices you want ruled on**, and the review findings needing a ruling. The user answers the whole set in one go — don't drip decisions one at a time, and don't ask for a line-by-line read of the design doc.

Hold agreed changes as chat-level deltas and **edit the doc once, when the gate closes**, updating the Reviewer summary to match — never rewrite per discussion point. Then offer `/clear` — the design doc is self-contained, so implementation can start fresh.

Emit the completion report:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ /design-feature — <id> <slug> decisions, seams and risks agreed
Pipeline: spec ✓ · [design] · implement · finish
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Did            • basis chosen from N candidates; N decisions + guiding principles; decomposition + seams; UI sketch; single-home register; test strategy
Artefacts      • specs/<id>-<slug>-design.md (updated once at gate close); specs/<id>-<slug>-ui.html + sketch Artifact URL <or: no UI surface / waived>
Review         • architecture lens + design skeptic: <verdicts + any findings>
Gate           • Respond to the decision sheet (decisions + sketch + findings, one set)
Next → /implement specs/<id>-<slug>-design.md   build it in vertical slices, one test at a time, verified RED per item
```
