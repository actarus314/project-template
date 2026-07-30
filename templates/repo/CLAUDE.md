# <project> — Claude Code instructions

> Local file, **ignored by Git**. Claude Code reads it automatically at every session.

## The project's rules live in AGENTS.md

@AGENTS.md

> `AGENTS.md` is **versioned** and read by every agent ([agents.md](https://agents.md) convention).
> It carries: commands, structure, branching policy, code conventions, checks, do-not-touch.
> **Do not duplicate here what already lives there** — two copies always drift.
> This file keeps only what is **personal** and has no business on GitHub.

## Organisation standard

https://github.com/actarus314/project-template/blob/main/docs/claude-code-project-standard.md

*(If a local clone of the template is available, read it from there instead — it is the same file.)*

## Workspace pointers (LOCAL git repo — no remote, never pushed)
- Secrets / auth: `../workspace/secrets.md`
- Docs / architecture: `../workspace/docs/` — **read `SUIVI.md` first after a `/clear`** *(the single living doc: state + what remains)*
- Plans / roadmap: `../workspace/plans/`
- Notes: `../workspace/notes/`

## GitHub auth — the non-interactive shell trap
- Claude Code's Bash tool spawns a **non-interactive** shell: the direnv hook **loads nothing**.
  → **prefix `git push` / `gh` with `direnv exec .`** (from `repo/`); it loads `.envrc` for that command.
  ⚠️ `direnv exec` **does not change the CWD**: from another folder, target `repo/` via `git -C repo`. Requires `direnv allow` (done at setup).
- The PAT lives in **`.envrc`** (`GITHUB_PAT`), never in `.env` (container leak via `env_file`).
- Remote as a **bare URL** — a PAT in the remote URL is a plaintext leak in `.git/config`.
- Without `direnv exec`, `git`/`gh` fall back to the public-RO PAT: an org may refuse it.

## Living docs — to keep up unprompted
- `../workspace/docs/SUIVI.md`: consolidate (state, decisions, what remains) · purge what shipped.
- `CHANGELOG.md` (versioned): a line under `Unreleased` for every user-facing change.

> No secret in this file (zero-secret discipline on any file named by convention).
