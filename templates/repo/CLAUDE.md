# <project> — Claude Code instructions

## The project's rules live in AGENTS.md

@AGENTS.md

**That import is the only reason those rules are read at all.** Claude Code reads this file at
every session, and nothing else on its own: without the import, `AGENTS.md` sits on disk and never
enters the agent's context — present, and invisible.

This file is therefore **versioned**, and deliberately almost empty: it carries the import, and
nothing else. What `AGENTS.md` holds — commands, structure, branching, conventions, the checks —
is **not** repeated here, because two copies drift.

## Anything personal goes elsewhere

Machine-specific paths, personal preferences, credentials: `~/.claude/CLAUDE.md` (that machine,
every project) or a local settings file, never this one. This file is committed.
