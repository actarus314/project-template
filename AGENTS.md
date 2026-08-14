# AGENTS.md — instructions for any code agent

To be read before touching anything in this repo.
This file follows the [AGENTS.md](https://agents.md) convention; Claude Code reads it via the `@AGENTS.md` import in `CLAUDE.md` — **versioned since 2026-08-07, precisely so that a clone reads these rules**: measured the day before, an agent started in a clone did not have this file in its context at all.

> **Language & tone**: this repo follows the standard's rule in full — see [`docs/claude-code-project-standard.md` §1](docs/claude-code-project-standard.md#1-basic-concepts) for what stays in French and why, and §15 for the bilingual `README.md` exception.

## What this is

This repo **builds and configures** projects, never one itself — what it is (and is not), and why: [`README.md`](README.md).

## Structure — TWO git repos, side by side, only one goes to GitHub

| | Remote | Content |
|---|---|---|
| **`repo/`** *(the cwd)* | → GitHub **public since 2026-07-31** — `actarus314/project-template` | the tools, `templates/`, `docs/`, `skills/` |
| **`../workspace/`** | ❌ **none — never pushed** | the tracking, the archives, the research |

**`skills/new-project/` is the CANONICAL version of the skill**, and `~/.claude/skills/new-project` is a **symlink** to it.
It used to live outside any repo: not versioned, not run through CI, not diffable — even though it drives the RUNBOOK, which changes every session. *(The integration audit found 5 drifts, including a command formally forbidden elsewhere in this repo.)* It sits at the **root**, never under `templates/` — and **not** because `init-project.sh` only copies from there. It also copies `check.sh`, `open-pr.sh`, `release-notes.sh`, `configure-repo.sh` *(which travels because a project changes its own status)*, **the whole of `checks/`** *(`cp "$TPL/checks/"verify-*.sh`, since every check detects its own perimeter and none has to be picked)*, **`.githooks/`** and **`.githooks-workspace/`** *(the neighbour's gate, which lives here because `core.hooksPath` is per-repository — one directory cannot arm both)* — all seven **from the ROOT**, never from `templates/`, because a second copy drifts. What protects the skill is that the copies are **named**: four files, two directories, plus one glob confined to `checks/verify-*.sh`. `skills/` is reached by none of them.

> 🔴 **`templates/repo/` is therefore NOT the full picture of what a generated project receives.** Reading it suggests a project ships without `check.sh`, without `open-pr.sh` and without `checks/` — it ships all three. They are **not duplicated under `templates/` on purpose**: the template runs them on itself, and a second copy would drift. **To see what a project really receives, generate one** *(`verify-travel.sh` does exactly that, and it is why it generates rather than reads)*.

`workspace/` **must NEVER gain a remote**: it carries private repo names and incident accounts. This is what lets `repo/` flip to public one day without cleaning anything up.

## Commands

```bash
./init-project.sh <project> <owner>/<repo> [parent] [--type static|node|generic] [--pages] [--artefact] [--staging]
./configure-repo.sh <owner>/<repo> [homepage] [description] [topics-csv] [--dry-run]
./check.sh   # replays the CI checks LOCALLY, at the pinned versions (local == github)
./open-pr.sh <base> <title> <body-file>   # opens a PR AND makes sure the CI actually starts (via direnv exec)
./release-notes.sh <tag> [previous-tag] < note.md   # composes the Release note: the text, then its two links
./fleet.sh   # which generated projects run behind this template — reads the projects the harness has seen
```

`configure-repo.sh` is **run by the maintainer** with an **ephemeral** admin PAT — the assistant **never** has `Administration: write`.

**The six commands above live at the ROOT; every sub-check lives in `checks/`** — nobody runs those by hand, `check.sh` calls them. **`fleet.sh` is the one that does NOT travel**: it serves whoever holds the template, never a project generated from it. *(`verify-checksums.sh` used to sit in `docs/` and its siblings at the root: one nature, two treatments.)*

`check.sh` reads the pinned versions in `ci.yml` *(single source)*, pulls the binaries under `.ci-tools/` *(gitignored)* and replays **everything the CI runs**: shellcheck · actionlint · zizmor · **semgrep** · **osv-scanner** · gitleaks — plus **two deliberate additions**: validation of any `renovate.json` present *(local-only — it catches the silent freeze of updates on a broken config)*, and the **house checks** under `checks/`. It is **auto-detecting** *(it reads the repo's `ci.yml` and runs ONLY what's found there)*, so the **same** file serves this repo AND every generated project.

🔴 **`./check.sh --house` is the CI's door** — the house checks and nothing else, since the CI pins and runs the external tools itself. **One line, in every gating workflow**, and `verify-checks-wiring.sh` fails the build if it ever leaves one. What passes locally passes the CI — but **the CI remains the authority**. *(Why one line and never a list — and which workflows carry it: [`docs/repo-controls.md`](docs/repo-controls.md).)*

The `pre-commit` hook **reruns it on its own, at every commit, and BLOCKS on a gap** *(gitleaks on staged files was already blocking)*. Escape hatch: `git commit --no-verify`, a decision, not an accident.
**The three rhythms — what triggers each, what runs in it, what it costs, and how to stretch the longest one — live in [`docs/repo-controls.md`](docs/repo-controls.md), and nowhere else.** They were once written out here too, with a duration that had drifted to less than half the measured one.

## Discipline — PR-only

**`repo/` is PR-only.** `main` is **never** written to directly: the `pre-push` hook refuses it, and since the public flip the **ruleset** refuses it server-side too. *(Which of the two actually blocks, and what a still-private generated project has instead: [`repo-controls.md`](docs/repo-controls.md).)*

- 🔴 **Open a pull request only on an instruction to open one, and NAME that instruction when doing it** — quote the words that authorise it, the way a merge quotes the green it relies on. Pushing needs no instruction and never has; opening does. *(Measured over this repository's transcripts: **49 %** of pull requests were opened with no instruction traceable to the maintainer.)*
- 🔴 **And before opening, ask whether the previous one carries the SAME undertaking — and if it does, commit onto its branch and push instead.** Pushing is free; a pull request costs a full CI run, and two of them for one undertaking buy nothing. The trap is that each batch looks coherent **in isolation**, which is exactly why the question has to be asked out loud rather than felt. *(Not the same statement as "one PR per `feat/` branch is the normal pace of work", `repo-controls.md` — that one describes the branch topology, this one is the gesture just before opening.)*
- Branch `feat/…` → **once instructed to open it** *(rule above — this line describes HOW, never WHETHER)*, **open the PR with `direnv exec <repo> ./open-pr.sh <base> <title> <body-file>`**: it pushes, opens the PR, AND **verifies that a `pull_request` run starts** — GitHub sometimes fails to dispatch the CI, and a PR with **0 runs** reads as green when it has **never** been tested. If it's missing, it closes/reopens to re-pull the event *(the only re-trigger that reproduces the REQUIRED `pull_request` checks)*. 🔴 **"0 runs" is NEVER a green.**
- A **CI** *(`.github/workflows/ci.yml`)* validates every PR: it lints its **own** workflows, generates projects and lints **their** workflows under real conditions.
- **Merge only on green CI.** This must be verified every time — never `gh pr checks` *(the `Checks` permission cannot be granted)*:
  ```bash
  sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
  gh run list --commit "$sha" --json workflowName,status,conclusion
  ```
  **Green ⇔ every expected workflow is `completed/success`**: `CI`, **+ `Publish image`** if `docker-publish.yml` exists *(the same set as the ruleset's required checks, derived the same way — so the human barrier used while private and the server that replaces it at the public flip say exactly the same thing)*. A workflow **missing** from the list is **not** a green: GitHub registers workflows **one by one** after a push, so for a few seconds `CI` can be `success` while `Publish image` does not exist yet. *"Nothing red" and "everything green" are not the same claim.* ⚠️ **This green is the MERGE criterion, and nothing more.** In particular it says nothing about a published artefact being usable: a green `Publish image` can leave the ghcr package **private and unpullable** — only an anonymous pull proves otherwise *(RUNBOOK §3)*. Measured 2026-08-06: read alone, this paragraph led to the conclusion that everything green meant the image was ready.
- **After the merge, also verify the `push` run on `main`** — a different event, so a different run: the PR's green says nothing about that one, and `main` is what counts.
  🔴 **`--commit` does NOT find this run — filter by BRANCH.** On a SHA born from a merge, `gh run list --commit <sha>` returns **0 runs**, while `--branch main` returns the `CI [push]` run carrying **exactly this `headSha`**, green. The `--commit` filter works on `pull_request` runs — hence the command above, which stays correct. Run as-is after a merge, it returns "0 runs": **the exact pattern this file teaches to read as a dispatch failure.**
  ```bash
  gh run list --branch main --limit 5 --json headSha,workflowName,event,status,conclusion \
    --jq "[.[]|select(.headSha|startswith(\"$sha\"))]"
  ```

## Conventions

- **Writing** — concise and plain, in **everything** written *(documents, comments, terminal output, commit messages)*, and a fact lives in **a single place**: both rules belong to [`docs/METHODE.md`](docs/METHODE.md), which states them and says what is measured.
- 🔴 **Where a document and the code disagree, the CODE decides what IS** — it is what runs. But a sentence that PRESCRIBES means the code is late, never that the sentence is wrong: which side gets corrected, and what settles it, [`docs/METHODE.md`](docs/METHODE.md).
- **`CHANGELOG.md`**: a line in `Unreleased` as soon as a change is visible **to whoever uses the repo** *(a template that changes, a RUNBOOK step that moves, a script's behavior)*. An internal refactor or a typo fix does not go there.
  **The FORM that line takes — imperative verb, the effect before the file name, 300 characters, and the pull request at the end — is [`docs/claude-code-project-standard.md` §16](docs/claude-code-project-standard.md#16-project-lifecycle-docs-and-what-a-project-ships)**, with the sources it comes from. `verify-changelog.sh` refuses what it can count; the rest is written in.
- **Version**: the **git tag** is the single source — `./init-project.sh --version` reads it, never a stored literal. `verify-version.sh` *(run by `check.sh` and by the CI)* fails the build if the tag, the CHANGELOG and the scripts disagree. Releasing is a deliberate action: **RUNBOOK §3**.
  🔴 **A BOT's pull request gets that line committed ONTO ITS BRANCH, before the merge** — never in a later one. Renovate rebases only on a conflict or on request, so the commit survives; and where it does not, the check goes red again, which is the point. A line written afterwards is a discipline, not a guard.

## Do not break

- **`~/.claude/CLAUDE.md` points via an ABSOLUTE path** to `docs/claude-code-project-standard.md`, `docs/METHODE.md` and `docs/RUNBOOK.md`. Moving them breaks **every** Claude Code session, **silently**.
- **`templates/repo/.envrc`, `templates/repo/CLAUDE.md` and `templates/repo/requirements-ci.txt` are tracked via `git add -f`**: the neighboring **template** `.gitignore` would otherwise ignore them *(`requirements-ci.txt` is DELIBERATELY so — excluded from the osv scan, see its comment in that `.gitignore`)*. **Never `git rm --cached` them.**
- **TWO symlinks point into `skills/` — `~/.claude/skills/new-project` AND `~/.claude/skills/housekeeping`** — so **moving either folder breaks its skill**, silently: it simply disappears from the list, with no error. To restore one: `ln -s <new path> ~/.claude/skills/<name>`. *(A copy instead of a link would be worse: it would drift, and that is exactly what produced 13 stale copies of the PAT recipes.)*
  🔴 **A test that removes only the first proves nothing about the second**: the surviving link masks the plugin, so the skill still resolves — and it resolves **unprefixed**, which is the tell. Both removed, both come back as `project-template:<name>` *(measured 2026-08-11)*.
- **Never commit a secret.** `.env` and `.envrc` are untracked, and must stay that way.
