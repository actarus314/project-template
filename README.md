# Project Template — Claude Code

This folder **builds and configures** projects. It is **not** a project.

The rule that structures everything: **what SERVES to create a project** and **what TELLS how this template was built** are two different things, and they no longer mix.

---

## Create a project

```bash
./init-project.sh <project> <owner>/<repo> [parent-folder] \
    [--type static|node|generic] [--pages] [--artefact] [--staging]
```

`--type` decides **only the toolchain** (which `ci.yml`). Everything else follows **three independent capabilities**:

| Capability | The question to ask | What it brings |
|---|---|---|
| `--pages` | Is the site served by **GitHub Pages**? | `pages.yml` |
| `--artefact` | Does the repo **publish an image that someone ELSE deploys**? | ghcr image · Trivy · tags ruleset · immutable releases |
| `--staging` | Is there a **host to VALIDATE** before prod? | `develop` branch · 3-stage flow |

> **`develop` follows from `staging`** — never from Docker, never from the language. A `node` project with no host to validate does not have one; a Pages site packaged as an image doesn't either.

**Shortcuts**: `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging` · `--type generic` ≡ **no capability** *(any other toolchain — Android, C/C++, Rust… : security checks only, build/test to fill in)*.

## Configure the repo server-side

```bash
./configure-repo.sh <owner>/<repo> [homepage] [description] [topics-csv] [--dry-run]
```

Rulesets, secret scanning, Dependabot alerts, immutable releases, Pages, description, **topics**, and **CodeQL activation** *(native default setup — it detects languages and keeps them up to date on its own; there is **no longer** a `codeql.yml`)*. **Run by the maintainer** with an **ephemeral** admin PAT — the assistant never has `Administration: write`.

⚠️ **Replayed on the switch to public**: a private repo on the Free plan has **neither ruleset, nor secret scanning, nor CodeQL**. The script is **idempotent**, that's what it's for — and it's this replay that **activates CodeQL** on the flip.
`--dry-run` reads everything and **writes nothing** — to be used on a live repo.

## Verify locally — `local == github`

```bash
./check.sh
```

Replays **the CI's security checks** at **pinned versions** (auto-detected from `ci.yml`, so nothing to maintain by hand): what passes here passes the CI. It is **copied into every generated project**, and a `pre-commit` hook replays it on its own — throttled (24h) and **advisory** (it has never blocked a commit).

## Which version am I running?

```bash
./init-project.sh --version
```

The **git tag** is the single source, because a ruleset makes it immutable — the scripts read it, they never store it *(the why: standard §12)*. `verify-version.sh`, run by `check.sh` and by the CI, fails the build if the tag, the changelog and the scripts ever disagree.

A generated project records the version that built it, in its own `AGENTS.md`: it carries a **frozen copy** of the templates, so knowing which one is what makes a later fix diffable.

---

## What's in this folder

The template applies to itself the tree structure it imposes *(standard §2)*: **two distinct git repos**, side by side.

```
template/
├── repo/         ← THIS folder. Versioned → GitHub. The tools and the reference.
└── workspace/    ← The project's memory. LOCAL git repo, no remote — never pushed.
```

| | Role |
|---|---|
| **`init-project.sh`** · **`configure-repo.sh`** · **`check.sh`** · **`open-pr.sh`** · **`verify-version.sh`** | **The tools.** What gets run. |
| **`templates/`** | **What gets COPIED into a project** — and nothing else. `repo/` (versioned files) · `workflows/` (CI) · `workspace/` (outside Git). |
| **`skills/`** | **`new-project/`** — the Claude Code skill that runs through the RUNBOOK, stopping at every action the maintainer must perform themselves. Canonical here, never under `templates/`: nothing duplicates into generated projects. |
| **`docs/`** | **The reference, to be read as needed.** The method, the standard, the runbook, the map of checks. |
| **`../workspace/`** | **How this template was built.** Log, decisions, research, defects found. To be read to understand *why*, never to *do*. |

### `docs/` — the reference

- 🎯 **`RUNBOOK.md`** — **the full lifecycle, end to end**: create · work · release a version · switch private→public · evolve · maintain. **It states the ORDER OF ACTIONS and WHO does them**; the standard states the *why*. **This is the operational document — start with it.**
- **`METHODE.md`** — **a single source of truth**: a fact lives in one place, everywhere else a link. **Read at every session** *(imposed by `~/.claude/CLAUDE.md`)*.
- **`claude-code-project-standard.md`** — the standard. **Read at every session** *(same)*.
- **`github-repo-config.md`** — server-side checks, PAT matrix, new-repo checklist.
- **`controles-repo.md`** / **`.html`** — which check runs, where, with what tool. The `.md` version is **authoritative**; the `.html` is its layout.

### At the root

**`AGENTS.md`** — read this before touching anything: structure, commands, the PR-only rule, what must not be broken. · **`CONTRIBUTING.md`** — how to open a PR here. · **`SECURITY.md`** — report a flaw **privately**, never as a public issue. · **`CHANGELOG.md`** — what changed, for whoever uses the repo.

### `../workspace/` — the build

- **`SUIVI.md`** — the log *(the hot one)*. **To open first** to resume work. Short, it **points** to the archives.
- **`archives/`** — *the cold one*: one folder per closed stage *(`conception/`, `tests-grandeur-nature/`, `template-sous-git/`)*, each **synthesized** *(what/how/why)*. The three pieces of research that settled things live in **`archives/conception/`**.

---

## Two things not to break

**The global pointer.** `~/.claude/CLAUDE.md` references `docs/` **via an absolute path**. Moving these files breaks every Claude Code session, silently.

**`workspace/` is not in this repo — and it must never enter it.** It carries the internal memory (private repo names, incidents). Its own git, **with no remote**, is what protects this repo the day it goes public.

---

## License — two of them, and the boundary matters

| What | License |
|---|---|
| **The tool** — scripts, docs, the skill | **PolyForm Noncommercial 1.0.0** *(`LICENSE`)* |
| **What the tool FABRICATES** — `check.sh`, `open-pr.sh`, everything under `templates/` | **MIT** *(`LICENSE-MIT`)* |

The exception is not a detail: `init-project.sh` copies those files **verbatim** into every project it generates. Under a single noncommercial license, **every generated project would inherit that restriction** — including projects whose author never asked for it and had no way of knowing. The tool is protected; what it produces is free.

🔴 **PolyForm Noncommercial is not an open source license** — the OSI definition forbids restricting the field of use — and GitHub therefore displays this repository as *"Other"*. That is deliberate, not an oversight.

