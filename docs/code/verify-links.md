# `checks/verify-links.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why a dead link matters more here

This repo runs on pointers, so a broken one silently turns "one source" back into "no source" — nothing renders an error, the reader lands nowhere and stops following.

## Scope, and the false positive that shaped it

The first manual pass read `docs/X.md` and `(…/releases/tag/vX.Y.Z)` — format EXAMPLES inside backticks — as dead links. Its only false positive, and why fenced and inline code are blanked before any link is looked for.
An `http(s)` target is someone else's uptime, out of scope. An anchor is checked against the headings it aims at — which is what makes a table of contents safe to write, a dead anchor scrolling to the top rather than raising anything.

## A pointer that puts words in a document's mouth

A link is checked, an **attribution** is not — one credited `METHODE.md` with a rule it never carried, while every link around it resolved.

**Only a QUOTED formula counts**, normalised on both sides — a paraphrase needs a judgement, which no check makes. Measured first: the repository held **2**, so no threshold to defend. 🔴 **Both fired, and both were real**: those scripts TRAVEL, and a generated project's `AGENTS.md` is another file — one formula differed by a word, the other named a section absent there.
