---
name: add-backlog-item
description: Quickly capture a new backlog item in docs/BACKLOG.md with a canonical ID and a brief summary. Use whenever a new idea, bug, or suggestion comes up — capture is cheap; the full spec comes later via /new-feature.
---

Capture, don't elaborate — a few lines, not a spec.

1. Take the next free ID from the "Next free IDs" line at the top of `../../../docs/BACKLOG.md` (`F` = feature, `B` = bug, `C` = code - non user facing improvement) and bump that line in the same commit. Retired IDs are never reused.
2. Add the entry to the right section with a brief summary (roughly 1–5 lines): what and why; key files, decisions, or constraints if already known; dependencies ("revisit after F88 B–C land").
3. Stash any uncommitted work, then create a new branch from the trunk with only the changes for the new backlog item.
4. Merge this branch into the trunk by the PIPELINE.md **merge into trunk** route.
5. Return the working tree to how it was before adding the backlog item — the original branch checked out and the stash popped. Mid-feature (called from `/new-feature`, `/implement` or `/finish-feature`), this puts you back on the feature branch with its uncommitted work intact.

Do **not** write a spec, design, or implementation plan at capture time. That happens only when the item is selected to work on next (`/new-feature`).
