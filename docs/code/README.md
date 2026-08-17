# `docs/code/` — the implementation notes

One note per file, owning **what it took to arrive at that code**: the measurement that set a value, the alternatives ruled out, what a reader needs to challenge the design.

🔴 **The constraint itself stays in the comment**, bare, beside the line it guards. A note carries what a comment must not: a figure, an alternative weighed, an incident.

**It owns nothing else.** The rule a check enforces is [`AGENTS.md`](../../AGENTS.md)'s to state, and a note restating one is a second source — the stale copy gets read.

These notes **travel** into every generated project, so they are written to be read WHERE THEY LAND. 🔴 **Naming a document this project does not hold is a pointer; restating it is not.** They live where it was generated from: https://github.com/actarus314/project-template/blob/main/docs/

🔴 **A `blocking:` header describes the EXIT CODE, not the wording** — any non-zero is a KO. Three once printed *(advisory)* while refusing the commit.

🔴 **A check imports nothing outside the standard library**, and all 29 hold that. They run at every commit, in CI, and in every generated project, so a third-party import is a dependency to install in each of them and a second way to skip in silence. **Ruling a tool out on that invariant is firmer than ruling it out on a measured rate**, which the next corpus moves.
