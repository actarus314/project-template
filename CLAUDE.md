# Claude Code instructions — this repository

## The rules live in AGENTS.md

@AGENTS.md

**That import is the only reason those rules are read at all.** Measured on 2026-08-06, on a clone
of this repository: an agent starting there reported that `AGENTS.md` was *not* in its context —
present on disk, and invisible. Nothing loads it on its own.

This file is therefore **versioned**, and deliberately almost empty: it carries the import, and
nothing else. What `AGENTS.md` holds — structure, commands, PR-only discipline, conventions, the
do-not-break list — is **not** repeated here, because two copies drift.

## The neighbouring workspace, when there is one

The maintainer's checkout has a `../workspace/` beside this repository — the tracking doc, the
archives, the research. It is **never pushed** *(the reason: the standard's decision rule, §3)*, so
a clone does not have it, and nothing here depends on it.

When it is there, `../workspace/SUIVI.md` is the entry point for picking the work back up: where
things stand, what remains, the known traps.

## Anything personal goes elsewhere

Machine-specific paths, personal preferences, credentials: `~/.claude/CLAUDE.md` or a local settings
file, never this one. This file is public.
