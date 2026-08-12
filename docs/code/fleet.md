# `fleet.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The list it reads is a cache, and calling it a registry would be the whole defect

`~/.claude/projects/` holds one folder per project **opened with Claude Code**, named after its absolute path.
Nothing declares a project there and nothing removes one: a project never opened is **invisible**, and a project moved leaves its old slug behind for good.
Both limits are printed with the table rather than left to be discovered — a fleet view that quietly under-counts is worse than none.

Measured on 2026-08-12: **23 slugs, 8 scratchpads or cleaned-up probes skipped, 3 dead paths, so 12 projects resolved**. The three dead ones are real — one project moved between two folders and left one slug per location behind.
🔴 **12 is a floor, not a total.** The count of slugs moves the moment a session opens anywhere; fewer than 12 resolved signals a regression of the dash-folding below, more slugs signals nothing at all.
⚠️ **The dead count was reading 6 the day before**, half of it test probes whose temporary directory had been cleaned up. A number meant to say *"look at this"* is worth nothing once routine noise is allowed into it.

## Folding the dashes — a blind substitution loses seven slugs out of eighteen

A slug replaced every `/` with a `-`, and **a folder name may itself contain a dash**, so the mapping is not reversible:

```
-Users-…-Projects-two-words-repo
   → /Users/…/Projects/two/words/repo    does not exist
   real: /Users/…/Projects/two-words/repo
```

Hence the walk: take the shortest segment that **exists on disk**, recurse, backtrack when the tail fails.
A table of known exceptions was the other option, and it was ruled out for the reason the method states — it is a second source, stale the day a folder is renamed, and its staleness is silent.

🔴 **Nothing says a slug has ONE reading.** `…-two-words-repo` can fold onto a real `two-words/repo` **and** a real `two/words-repo`, and stopping at the first found made the other disappear without a line. Every reading is now collected and the row is marked `⚠N`, the first one being what it shows: the walk cannot know which is meant, and the reader can.
The price is that the space is always walked whole, so it is capped at **2 000 steps** — a slug resolving to nothing branches at every one of its dashes, and only the filesystem was stopping it. Measured over the 23 slugs of this machine: **0.28 s stopping at the first, 0.69 s walking all of them**.
⚠️ **2 000 is an arbitrary ceiling, and reading it as a measured one would be the mistake**: the worst real slug here costs **8 steps**, so the cap sits 250 times above it. It is not there to bound a cost — it is there so that a pathological tree cannot make the walk run away, and a number close to the real cases would turn a slow project into a truncated one.

## Why `CLAUDE_PROJECTS_DIR` exists

Without it, the "behind the template" state cannot be exercised at all: the real list holds no generated project running late, and fabricating one means pointing the script at a built directory of slugs.
⚠️ The scratchpad filter drops the `-private-tmp-` and `-tmp-` prefixes outright. A probe project created by `mktemp -d` lands under `/var/folders/…` on macOS and is **deliberately not** dropped — which is precisely what lets a constructed fleet carry a positive case.
🔴 **Deliberate while it exists, noise once it is gone**: the temporary directory is cleaned up, the slug stays, and the probe was landing among the dead paths. A `/var/folders` slug that no longer resolves is therefore counted with the scratchpads, never with the dead — **the two prefixes are read at two different moments, and that is the whole point**. Filtering them at the top like the others would have silently removed the ability to test a late project at all.

## The column that identifies — the folder's own name identifies nothing

The standard layout is `<project>/repo`, so a resolved path ends on `repo` for **every** generated project: the first table printed **five rows named `repo` out of twelve**, and a fleet view whose rows cannot be told apart answers no question at all.
The row therefore steps up to the parent folder whenever the leaf is `repo` — the project's name is the folder holding the two repositories, which is what the standard makes stable.

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
