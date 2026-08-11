# `fleet.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The list it reads is a cache, and calling it a registry would be the whole defect

`~/.claude/projects/` holds one folder per project **opened with Claude Code**, named after its absolute path.
Nothing declares a project there and nothing removes one: a project never opened is **invisible**, and a project moved leaves its old slug behind for good.
Both limits are printed with the table rather than left to be discovered — a fleet view that quietly under-counts is worse than none.

Measured on 2026-08-11: **22 slugs, 5 scratchpads skipped, 5 dead paths, so 12 projects resolved**. Two of the dead ones are probe projects generated for these very tests; three are real — one project moved between two folders and left one slug per location behind.
🔴 **12 is a floor, not a total.** The count of slugs moves the moment a session opens anywhere; fewer than 12 resolved signals a regression of the dash-folding below, more slugs signals nothing at all.

## Folding the dashes — a blind substitution loses seven slugs out of eighteen

A slug replaced every `/` with a `-`, and **a folder name may itself contain a dash**, so the mapping is not reversible:

```
-Users-…-Projects-two-words-repo
   → /Users/…/Projects/two/words/repo    does not exist
   real: /Users/…/Projects/two-words/repo
```

Hence the walk: take the shortest segment that **exists on disk**, recurse, backtrack when the tail fails.
A table of known exceptions was the other option, and it was ruled out for the reason the method states — it is a second source, stale the day a folder is renamed, and its staleness is silent.

## Why `CLAUDE_PROJECTS_DIR` exists

Without it, the "behind the template" state cannot be exercised at all: the real list holds no generated project running late, and fabricating one means pointing the script at a built directory of slugs.
⚠️ The scratchpad filter matches the `-private-tmp-` and `-tmp-` prefixes only. A probe project created by `mktemp -d` lands under `/var/folders/…` on macOS and is therefore **not** filtered — which is precisely what lets a constructed fleet carry a positive case.

## It parses no stamp, and that is the point

Reading the stamp lives in `hooks/check-template-version.sh`, called once per project.
Written here too, the rule for recognising a stamp would exist twice and the two copies would drift — the loop calls the check and relays its **first line whole**.
🔴 **Whole, never sliced**: the state characters `⚠ ✓ ·` are multi-byte, and cutting the first character under a non-UTF-8 locale hands back a truncated byte. Nothing guarantees a hook's `LANG`. The state stays readable because it opens the line.

## Alternatives ruled out

| Ruled out | Why |
|---|---|
| **Enumerating a GitHub account's repositories** | Sees one account, costs one API call per repository, and misses every local project never pushed. The harness list is free and local. |
| **Keeping a fleet file** | A second source, stale the moment a project is born or disappears. |
| **Dropping the fleet view, and detecting per project only** | Loses the benefit that decided the design: one single place to ask the question. |
