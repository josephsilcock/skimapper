# Area docs — the definitive target state

One living document per **product area** (not per delivery increment). Each doc is the definitive
statement of the *intended user-facing behaviour* of its area, as currently built. Together they are
the requirements-of-record for the whole application.

| Doc | Area |
|-----|------|
| [resorts.md](resorts.md) | The resort list: what is listed, its order and rows, freshness, the failure states, the app's visual basis |

---

## Register

- **Requirements-first**: bullets answering "what is the intended user-facing behaviour". User-visible
  state names, behavioural rules and constraints stay; implementation detail derivable from code
  (handlers, procs, tables, HTTP codes, job names) does not.
- **Present state only** — no history, no spec/commit references, and no future: deferred or
  unbuilt work lives in BACKLOG.md, not here. Git history holds the past.
- **No backlog/bug references** — BACKLOG entries may point at these docs, never the reverse. An
  open question surfaced during a change may sit inline in *italics* only until triaged; it then
  becomes a plain behaviour statement, a BACKLOG item, or a fix.
- Each doc ends with a short "Entry points (navigation aid)" footer into the code.
- Cross-area handoffs are one-line references to the sibling doc, not restatements.

## Lifecycle

- `/new-feature` **reads** the relevant area doc(s) before writing the spec, and `/design-feature`'s
  design doc carries a *Definition delta* section stating how they will change.
- `/finish-feature` **applies** the delta — merging as-built behaviour in and deleting superseded
  text in the same edit (a doc must never describe both the old and new model) — records noteworthy
  decisions in `../DECISIONS.md`, then deletes the merged spec and design doc.
- A new area doc may be added only when behaviour genuinely fits none of the existing ones; prefer
  extending an existing doc. Add each new doc to the table above.