# Conventions

This document defines naming conventions, code organisation, and style guidelines for the codebase.

---

## General Principles

### Code Style
- **Clarity over cleverness**: Prefer explicit, readable code
- **Consistency**: Follow established patterns in the codebase
- **Locality**: Keep related code close together
- **Single Responsibility**: Each class/function does one thing well
- **Immutability**: Prefer immutable data structures where practical

### Naming
- **Be descriptive**: Names should clearly convey intent
- **Avoid abbreviations**: Use `resort` not `rsrt` or `res`
- **Be consistent**: Use the same name for the same concept everywhere
- **Domain language**: Use terminology from the problem domain

### Comments
- **Comment for the unfamiliar reader, not the conversation**: a comment earns its place only when someone reading the code cold would otherwise be confused or get it wrong. Explain *why* — a non-obvious constraint, a subtle invariant, a deliberate-looking-wrong choice, an external gotcha.
- **Don't narrate spec decisions**: do not retell which option we picked in a spec discussion, the history of how a rule evolved, or minor rationale that the code already makes plain. The spec, `docs/DECISIONS.md`, and git history are the homes for that — link a spec/decision ID (`// F49: <reason>`) rather than transcribing it.
- **Default to none**: if the code is self-explanatory, leave it uncommented. Prefer a clearer name or a small extraction over a comment that compensates for unclear code.

### Method altitude & narrative flow
Readability is a first-class goal, and the most common way we lose it is methods that mix levels of abstraction.

- **One altitude per method.** When you start diving into mechanics mid-method, extract them behind an intention-revealing name and keep the top-level flow visible.
- **Isolate irreducible complexity; don't inline it.** Genuinely intricate logic (e.g. an allocation algorithm) is fine — put it behind one well-named call so the caller stays legible. A reader should follow *what* happens without reading *how*, descending only where they care.
- **Smells that mean "extract now":** a method that needs section-comment headers to navigate; threading three-plus loose collections between phases (bundle them in a record); a `Handle` that doesn't fit on a screen; the same intermediate shape rebuilt at multiple call sites.
- Prefer a clearer name or a small record/extraction over a comment that compensates for an opaque block.

---

## Git Conventions

### Branch Names
```
feature/route-planner
feature/piste-map-overlay
bugfix/lift-status-refresh
hotfix/critical-security-issue
refactor/extract-common-logic
docs/update-architecture-guide
```

### Commit Messages
```
# Format: <type>: <subject>

# Types: feat, fix, refactor, docs, test, chore, style, perf

feat: add resort search with filters
fix: correct run difficulty colour mapping
refactor: extract permission check to service
docs: update API documentation for routes endpoint
test: add integration tests for route creation
chore: update dependencies to latest versions
style: format code with prettier
perf: optimize resort list query
```

### Commit Message Guidelines
- Use imperative mood ("add" not "added")
- Start with lowercase
- No period at the end
- Keep subject under 70 characters
- Add body for complex changes

Example:
```
feat: warn when a route includes a closed lift

Check each lift on a saved route against the resort's current
lift status and flag closed ones in the route summary, so the
skier can re-plan before setting off.

Implements: F12
```
