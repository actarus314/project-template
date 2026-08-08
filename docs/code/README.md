# `docs/code/` — the implementation notes

One note per file, owning the **implementation** constraints of that file: why the code is written the way it is, what would break if it were written otherwise.

**It owns nothing else.** The rule a check enforces — and where a fact may live — is [`AGENTS.md`](../../AGENTS.md)'s to state. A note restating a rule is a second source, and the stale copy gets read.

These notes **travel**, beside the checks they document, into every generated project. So they are written to be read WHERE THEY LAND: pointing at a file only the generating repo holds is a dead end there, and a check says so.

🔴 **A `blocking:` header describes the EXIT CODE, not the wording** — `check.sh` turns any non-zero into a KO. Three once printed *(advisory)* while refusing the commit.
