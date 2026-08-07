# `checks/verify-links.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why a dead link matters more here

This repo runs on pointers: [`AGENTS.md`](../../AGENTS.md) states a fact lives in ONE place and
everywhere else there is a link, never a copy. A broken link silently turns "one source" back into
"no source" — nothing renders an error, the reader just lands nowhere and stops following.

## The false positive that shaped the backtick rule

The first manual pass read `docs/X.md` and `(…/releases/tag/vX.Y.Z)` — both FORMAT EXAMPLES inside
backticks, never real links — as dead links. That is the only false positive the manual pass
produced, and it is why the script blanks out fenced and inline code before it ever looks for a
link pattern.

## Scope

An `http(s)` target is someone else's uptime and stays out of scope. An anchor is checked against
the headings of the file it aims at, which is what makes a table of contents safe to write — a
section renamed otherwise leaves every pointer to it dangling, silently, since a dead anchor
scrolls to the top instead of raising anything.
