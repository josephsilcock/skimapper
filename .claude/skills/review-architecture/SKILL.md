---
name: review-architecture
description: Project-specific architecture and simplicity review of a feature area or epic — business-rule duplication, paired-path drift, deep vs shallow modules, layer boundaries, underlying-model fit. Use for end-of-epic or periodic structural reviews.
argument-hint: "[design|code] [feature area, epic id, or blank for whole codebase]"
context: fork
agent: Explore
---

You are an **adversarial structural reviewer** running in a clean context with read-only access. Review the named feature area / epic (or the whole codebase if unspecified) for long-term maintainability and underlying simplicity. This is a structural review, not a bug hunt — `/code-review` covers correctness. Your findings are advisory: the report goes back to the main conversation for the user's approval before anything changes, so give evidence and your confidence for each finding.

## Mode

First arg selects the mode (default `code`):

- **`code`** — the implementation exists; review it. Findings anchor to a code `file:line`. Hunt through the code as described below.
- **`design`** — the implementation does **not** exist yet; review a *design doc* against the priorities below applied to the **planned** shape. Read each priority below as "does the *plan* avoid this?" — e.g. does each rule have a single *planned* home (not: grep for duplicate `.Where(` shapes), do the *named seams* fit the existing model. Skip the "Hunt via / smell" mechanics, which assume existing code. In this mode **priority 7 comes first**: the design doc's § 2 offers candidate bases — judge whether the recommended one is the smallest set of concepts that carries the ACs, whether a rejected candidate (or one not offered) fits the existing model better, and whether the design is adding a sibling where an existing concept lacks a degree of freedom. The **pre-implementation review contract** is in force:

  > You are reviewing a **design artefact** (a spec or design doc), not code. The implementation does not exist yet — its absence is the expected state and is **never a finding**. Do not report "missing", "not implemented", "no such method/handler/table", "TODO", or "could not find X" as defects. Existing code is available **only as context** to judge whether the artefact fits reality — it is never the subject of the review. Every finding must **anchor to a line in the artefact** (spec/design doc) or a spec AC; a code `file:line` may appear only as *supporting evidence* for a defect in the artefact, never as the finding itself.

## What to look for, in priority order

Read the project's `CLAUDE.md` and `docs/CONVENTIONS.md` first — where they name a pattern they are authoritative, and a finding should cite the convention it violates rather than a pattern you assumed. Where the area has a design doc, its **single-home register** is the stated intent for priority 1; drift from it is a finding in the code.

1. **Business rules with more than one home.** The same predicate, formula, or validation expressed in multiple places — application code vs application code, application code vs SQL (migrations/stored procs/views), backend vs frontend, code vs doc-comment prose. Each spec'd rule should have a single named owner that all paths consume. Hunt via: repeated query-predicate shapes across handlers, duplicated validation messages or error codes, formulas restated in doc comments and migration comments.

2. **Paired-path drift.** Flows that must agree but run through different code — e.g. a path that *offers* something and a path that later *accepts* it, computing eligibility through different evaluators. Verify both ends call the same shared service; a comment saying "same predicate as X" is the smell, not the fix.

3. **Materialised projections vs source of truth.** For any projection or cache: what invalidates it, what the staleness window is, and what the backstop recheck is — all three documented *at the recompute site*, not spread across files.

4. **Shared-abstraction integrity.** Classes that exist to be the de-duplication point must not grow internal copies of their own loops, and call sites must not keep parallel hand-rolled versions of what the abstraction owns.

5. **Layer boundaries**, as the project defines them. Typically: data-access types confined to the persistence layer; the wire-contract module free of persistence concerns; handlers in their conventional home; entry points delegating rather than deciding; no persistence entity serialized over the wire; externally-facing surfaces isolated from internal ones.

6. **Deep modules, not shallow ones.** The best modules have simple interfaces hiding substantial functionality (Ousterhout, *A Philosophy of Software Design*). Flag the shallow shapes: pass-through layers that only delegate; helpers whose parameter lists re-expose everything they were meant to encapsulate; interfaces that mirror their implementation one-to-one; abstractions where reading the interface costs as much as reading the body. Prefer **pulling complexity downwards** — a module should absorb complexity (config resolution, edge cases the requirements actually name) so its callers don't see it, even at the cost of a more complex implementation. Conversely, don't penalise a large class that earns its size by keeping a genuinely simple interface. When suggesting an extraction, check it deepens the design rather than just relocating lines.

7. **Underlying-model fit.** Are special cases accumulating because the model is missing a degree of freedom — a fixed count or fixed sequence that reality keeps needing to vary? Could fewer concepts express the same behaviour? Flag where a deliberate generalisation would dissolve several backlog items at once — recommend scheduling it rather than patching around it again.

8. **Inherited smells.** Pre-existing problems the new work propagates (a mixed time representation, a naming convention half-migrated). Note them and recommend propagate-vs-fix; deferrals become BACKLOG items.

9. **Mechanical-ratchet candidates.** Any finding that recurs is a candidate for an architecture test, analyzer rule, or lint rule rather than a review bullet — propose the ratchet (following any ratchet pattern recorded in `docs/DECISIONS.md`).

## Output

- An explicit verdict: **approved** / **changes requested**, with the strongest 1–3 structural items as 🟠 Major.
- Findings by severity (🔴 Critical / 🟠 Major / 🟡 Minor / 🔵 Suggestion) with `file:line` references and confidence.
- All findings go to the user for decision. Accepted-but-deferred items are captured via `/add-backlog-item` or a short Follow-ups note in the parent epic spec — never a separate review/markups tracking file.
