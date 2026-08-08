# `docs/code/` — the implementation notes

One note per file, owning **what it took to arrive at that code**: the measurement that set a value, the alternatives ruled out, what a reader needs in order to challenge the design.

🔴 **The constraint itself stays in the comment**, bare, beside the line it guards. A note carries what a comment must not: a figure, an alternative weighed, an incident.

**It owns nothing else.** The rule a check enforces — and where a fact may live — is [`AGENTS.md`](../../AGENTS.md)'s to state. A note restating a rule is a second source, and the stale copy gets read.

These notes **travel**, beside the checks they document, into every generated project. So they are written to be read WHERE THEY LAND: pointing at a file only the generating repo holds is a dead end there, and a check says so.

🔴 **A `blocking:` header describes the EXIT CODE, not the wording** — `check.sh` turns any non-zero into a KO. Three once printed *(advisory)* while refusing the commit.
