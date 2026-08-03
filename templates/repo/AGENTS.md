# AGENTS.md — instructions for coding agents

Read this before changing anything in this repository.
This file follows the [AGENTS.md](https://agents.md) convention and is read by most coding
agents. Claude Code reads it through the import in `CLAUDE.md` (local, untracked).

> Scaffolded by **project-template `<template-version>`**.
> This project carries a **frozen copy** of that version's templates: a later fix to the template
> does **not** reach it on its own. This line says which version to diff against — it is a
> snapshot of the past, not a claim about the present.

## Project

- **What it is**: <one line>
- **Stack**: <technologies>

## Commands

```bash
<run command>        # run locally
<test command>       # tests
<lint command>       # lint / typecheck
```

## Structure

- `<dir>/` — <what lives there>

<!-- BRANCHING -->

## Conventions

- **Everything committed is written in English** — code, code comments, docs, `README.md`,
  `.env.example`. The only exception is `README.md`, which is bilingual (English, then French).
- **Never use the second person** (`you`/`your`) in committed content or in the app's UI.
  Write "the user", or use impersonal phrasing.
- **i18n**: translations live in a separate dictionary — never inline ternaries in the markup.
- **`CHANGELOG.md`**: update the `Unreleased` section for any user-facing change. The GitHub
  Release carries the auto-generated list of merged pull requests; the changelog says what
  actually changed for a user.
- **Architecture decisions**: a non-trivial decision (stack, schema, boundary) gets a short
  record in `docs/adr/`. The point is to preserve the *why*, which the code cannot express.

## While the repository is PRIVATE — the rules are NOT enforced by the server

A private repository on a Free plan has **no rulesets**: every check below still runs, but
**none of them is required** — GitHub would accept a direct push to `main`, or the merge of a
red pull request. The safety net is local, and partly human.

- **Open PRs with `./open-pr.sh <base> <title> <body-file>`** — it pushes, opens the PR, and
  confirms a `pull_request` run actually starts. GitHub intermittently fails to dispatch the CI
  run; a PR with **0 runs** looks like a pass but was never checked. If none appears it
  close/reopens the PR to re-fire the event. **"0 runs" is never green.**
- **Never merge a pull request whose CI is not green.** Nothing on the server prevents it.
  Check first, every time:

  ```bash
  sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
  gh run list --commit "$sha" --json workflowName,status,conclusion
  ```

  **Green means: every EXPECTED workflow is `completed / success`** — `CI`, plus `Publish image`
  when `docker-publish.yml` exists, plus **`CodeQL` once the repository is public** (it does not
  run while private: Advanced Security is unavailable there). **A workflow MISSING from that list
  is not a green**: it has simply not reported yet. "Nothing is red" and "everything is green" are
  not the same claim, and the gap between them is exactly where a broken change slips into `main`.

  > ⚠️ **Match on `workflowName`, never on `name`.** CodeQL runs through GitHub's *default setup*,
  > so it has no workflow file in the repository: its run is `dynamic`, and its `name` field reads
  > `Push on main` — the run's *title*, not the workflow's. Only `workflowName` says `CodeQL`.
  > A check filtering on `name` would never see CodeQL at all, and would call the pull request
  > green while the security analysis had not reported.
  >
  > ```bash
  > gh run list --commit "$sha" --json workflowName,status,conclusion
  > ```

  > `gh pr checks` cannot be used here. It reads `statusCheckRollup`, which needs the `Checks`
  > permission — and that permission **does not exist** in the fine-grained token UI, so it cannot
  > be granted (github/community#129512). The command above needs only `Actions: read`, which the
  > repository token already has.

- **After the merge, check the `push` run on `main` too.** It is a *different event*, so it is a
  different run: the pull request being green says nothing about it. `main` is what ships.

  > 🔴 **`--commit` does NOT find that run — filter by branch.** On a SHA created by a merge,
  > `gh run list --commit <sha>` returns **0 runs**, while
  > `--branch main` returns the `CI [push]` run carrying **exactly that `headSha`**, green. The
  > `--commit` filter works on `pull_request` runs, which is why the command above is correct
  > where it stands. Read as-is after a merge, it yields "0 runs" — the very pattern this file
  > teaches to treat as a failed dispatch. It would report a hole where everything passed.
  >
  > ```bash
  > gh run list --branch main --limit 5 --json headSha,workflowName,event,status,conclusion \
  >   --jq "[.[]|select(.headSha|startswith(\"$sha\"))]"
  > ```

- **Never push straight to `main` or `develop`.** The `pre-push` hook refuses it; that hook is
  the stand-in for the ruleset that does not exist yet. Work through a pull request, always.
- These constraints **disappear on their own** when the repository goes public: the rulesets
  then require the checks, and the server enforces what discipline alone was holding.

> This is the failure mode these rules close: a config regression no build step catches reaches
> `main`, ships as `:latest`, and a host pulls it before anyone notices.

## Checks that run

- **pre-commit hook** — `gitleaks` on staged files (a commit carrying a secret is rejected), then a
  throttled, CONSULTATIVE replay of `./check.sh` (≤ once / 24 h) — it surfaces drift, never blocks.
- **pre-push hook** — refuses a direct push to `main` / `develop` (the missing ruleset).
  Both hooks: a fresh clone must re-arm them once: `git config core.hooksPath .githooks`.
- **`./check.sh`** — replays the CI's security checks locally at the pinned versions, so `local == github`.
- **`./open-pr.sh`** — opens a PR and makes sure CI starts on it (GitHub sometimes drops the dispatch).
- **CI** (on every pull request, and required before merge) — `gitleaks` over the *full* history,
  `actionlint` + `zizmor` on the workflows, `semgrep` static analysis, `osv-scanner` on every
  manifest it discovers (`-r .`; CI-only tooling is out of scope via .gitignore), then the project's own tests.
- **CodeQL** — security analysis; a finding blocks the merge.

## Do not touch

- <vendored code, generated files, submodules…>
- Never commit a secret. `.env` and `.envrc` are untracked, and must stay that way.
