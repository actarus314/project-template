# Workspace — <project>

Everything personal. **This folder is a separate git repo, LOCAL: it has NO remote and must never gain one.**
It is the project's memory — without git, any deletion here would be irreversible.

- `docs/`      : living docs — `SUIVI.md` (the HOT one: cold-start resumption, it POINTS; also carries "what remains") · `archives/<stage>/` (the COLD one: one **synthesis** per closed stage — what/how/why)
                 The log **breathes**: it grows during a stage, shrinks when it closes (prune + synthesize into `archives/`, never a dump).
                 ⚠️ **ADRs are NOT here**: they are **versioned** in `repo/docs/adr/` (immutable, public).
- `plans/`     : execution plans, roadmap
- `notes/`     : scratch, drafts, conversation captures
- `secrets.md` : auth procedures, API keys, expiry dates — **NEVER commit**
