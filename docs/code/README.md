# `docs/code/` — the implementation notes

One note per file, owning the **implementation** constraints of that file: why the code is
written the way it is, what would break if it were written otherwise.

**It owns nothing else.** What a check looks for and what it triggers belong to
[`repo-controls.md`](../repo-controls.md); the rule it enforces belongs to
[`METHODE.md`](../METHODE.md). A note that restates either of those is a second source, and the
stale copy is the one that gets read.

The `verify-*.md` notes **travel** into every generated project, beside the checks they document.
