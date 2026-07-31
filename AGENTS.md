# AGENTS.md — instructions for any code agent

To be read before touching anything in this repo.
This file follows the [AGENTS.md](https://agents.md) convention; Claude Code reads it via the `@AGENTS.md` import in `CLAUDE.md` (local, untracked).

> **Language**: everything versioned in this repo is in English, just like everything it generates — only local file templates (`templates/repo/CLAUDE.md`, `templates/repo/.envrc`, `templates/workspace/*`) stay in French, since they are gitignored in the generated project.

## What this is

This repo **builds and configures** projects. **It is not a project.**
Its product is the **standard** *(the manual version of project deployment)*; the scripts are only its **automation**.

## Structure — TWO git repos, side by side, only one goes to GitHub

| | Remote | Content |
|---|---|---|
| **`repo/`** *(the cwd)* | → GitHub **private** — `actarus314/project-template` | the tools, `templates/`, `docs/`, `skills/` |
| **`../workspace/`** | ❌ **none — never pushed** | the tracking, the archives, the research |

**`skills/new-project/` is the CANONICAL version of the skill**, and `~/.claude/skills/new-project` is a **symlink** to it.
It used to live outside any repo: not versioned, not run through CI, not diffable — even though it drives the RUNBOOK, which changes every session. *(The integration audit found 5 drifts, including a command formally forbidden elsewhere in this repo.)*
It sits at the **root**, never under `templates/`: `init-project.sh` copies **exclusively** from `templates/`, so nothing here gets duplicated into generated projects.

`workspace/` **must NEVER gain a remote**: it carries private repo names and incident accounts. This is what lets `repo/` flip to public one day without cleaning anything up.

## Commands

```bash
./init-project.sh <project> <owner>/<repo> [parent] [--type static|node|generic] [--pages] [--artefact] [--staging]
./configure-repo.sh <owner>/<repo> [homepage] [description] [topics-csv] [--dry-run]
./check.sh   # replays the CI checks LOCALLY, at the pinned versions (local == github)
./open-pr.sh <base> <title> <body-file>   # opens a PR AND makes sure the CI actually starts (via direnv exec)
```

`configure-repo.sh` is **run by the maintainer** with an **ephemeral** admin PAT — the assistant **never** has `Administration: write`.

`check.sh` reads the pinned versions in `ci.yml` *(single source)*, pulls the binaries under `.ci-tools/` *(gitignored)* and replays **everything the CI runs**: shellcheck · actionlint · zizmor · **semgrep** · **osv-scanner** · gitleaks — plus **two deliberate additions**, which the CI does **not** run: validation of any `renovate.json` present *(it catches the silent freeze of updates on a broken config)*, and the **second-person** check *(standard §1 — the rule held by discipline alone until it was found in 9 files, 4 of them templates shipped into every generated project)*. 🔴 **Being local-only, neither is a gate**: they warn here, nothing blocks a PR on them. It is **auto-detecting** *(it reads the repo's `ci.yml` and runs ONLY what's found there)*, so the **same** file serves this repo AND every generated project. What passes locally passes the CI — but **the CI remains the authority** *(it alone verifies the SHA256 of Linux assets and runs under real conditions)*.

The `pre-commit` hook **reruns it on its own, throttled (24h) and CONSULTATIVE**: on the 1st commit of a window it replays `check.sh` and shows the result without **ever** blocking *(the only blocking the hook still does is gitleaks on staged files)*. To adjust the delay: `CHECK_MAX_AGE_HOURS`. Goal: no longer having to think about it, without turning an unrelated lint into a stuck commit.

## Discipline — PR-only

**`repo/` is PR-only.** `main` is **never** written to directly: the `pre-push` hook refuses it *(it stands in for the ruleset, absent as long as the repo is private)*.

- Branch `feat/…` → **open the PR with `direnv exec <repo> ./open-pr.sh <base> <title> <body-file>`**: it pushes, opens the PR, AND **verifies that a `pull_request` run starts** — GitHub sometimes fails to dispatch the CI, and a PR with **0 runs** reads as green when it has **never** been tested. If it's missing, it closes/reopens to re-pull the event *(the only re-trigger that reproduces the REQUIRED `pull_request` checks)*. 🔴 **"0 runs" is NEVER a green.**
- A **CI** *(`.github/workflows/ci.yml`)* validates every PR: it lints its **own** workflows, generates projects and lints **their** workflows under real conditions.
- **Merge only on green CI.** This must be verified every time — never `gh pr checks` *(the `Checks` permission cannot be granted)*:
  ```bash
  sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
  gh run list --commit "$sha" --json workflowName,status,conclusion
  ```
  Green = **every** expected workflow is `completed/success`. A workflow **missing** from the list is **not** a green.
- **After the merge, also verify the `push` run on `main`** — a different event, so a different run: the PR's green says nothing about that one, and `main` is what counts.
  🔴 **`--commit` does NOT find this run — filter by BRANCH.** On a SHA born from a merge, `gh run list --commit <sha>` returns **0 runs**, while `--branch main` returns the `CI [push]` run carrying **exactly this `headSha`**, green. The `--commit` filter works on `pull_request` runs — hence the command above, which stays correct. Run as-is after a merge, it returns "0 runs": **the exact pattern this file teaches to read as a dispatch failure.**
  ```bash
  gh run list --branch main --limit 5 --json headSha,workflowName,event,status,conclusion \
    --jq "[.[]|select(.headSha|startswith(\"$sha\"))]"
  ```

## Conventions

- Everything versioned is in **English**, here and in the generated projects.
- **Docs**: one idea per sentence, one sentence per line. A fact lives in **a single place** — everywhere else, a link *(see `docs/METHODE.md`)*.
- **`CHANGELOG.md`**: a line in `Unreleased` as soon as a change is visible **to whoever uses the repo** *(a template that changes, a RUNBOOK step that moves, a script's behavior)*. An internal refactor or a typo fix does not go there.
- **Version**: the **git tag** is the single source — `./init-project.sh --version` reads it, never a stored literal. `verify-version.sh` *(run by `check.sh` and by the CI)* fails the build if the tag, the CHANGELOG and the scripts disagree. Releasing is a deliberate action: **RUNBOOK §3**.

## Do not break

- **`~/.claude/CLAUDE.md` points via an ABSOLUTE path** to `docs/claude-code-project-standard.md`, `docs/METHODE.md` and `docs/RUNBOOK.md`. Moving them breaks **every** Claude Code session, **silently**.
- **`templates/repo/.envrc`, `templates/repo/CLAUDE.md` and `templates/repo/requirements-ci.txt` are tracked via `git add -f`**: the neighboring **template** `.gitignore` would otherwise ignore them *(`requirements-ci.txt` is DELIBERATELY so — excluded from the osv scan, see its comment in that `.gitignore`)*. **Never `git rm --cached` them.**
- **`~/.claude/skills/new-project` is a SYMLINK to `skills/new-project/`** — so **moving this folder breaks the skill**, silently: it simply disappears from the list, with no error. To restore it: `ln -s <new path> ~/.claude/skills/new-project`. *(A copy instead of a link would be worse: it would drift, and that is exactly what produced 13 stale copies of the PAT recipes.)*
- **Never commit a secret.** `.env` and `.envrc` are untracked, and must stay that way.
