# Organization Standard — Claude Code Projects

> Personal reference. Applies to every new project built with Claude Code (via Claude Desktop or CLI).
> Goal: simple, replicable organization, backupable as a single folder, with a clean separation between what goes on GitHub and what stays private.

**This document answers one question: *where does this go?*** It owns the layout, the decision rule, the `.gitignore`, the README, and what a project ships. Everything else has its own file — **one subject, one owner** — and this is the index of it.

| To… | Read |
|---|---|
| **found** a project — layout, where a file goes, what it ships | **this document** *(§1-3, §9, §15, §16, §19)* |
| **authenticate** without leaking — secrets, the PAT model, the permission matrix | [`secrets-and-auth.md`](secrets-and-auth.md) |
| **configure the assistant** — `CLAUDE.md`, `.claude/`, memory, delegation | [`claude-code-setup.md`](claude-code-setup.md) |
| **ship and verify** — branches, the version pin, repo config, the control matrix | [`repo-controls.md`](repo-controls.md) *(+ its `.html` view)* |
| **keep up to date** — the bump channels, Renovate, the PR checks | [`security-and-updates.md`](security-and-updates.md) *(+ its `.html` view)* |
| **deploy** a self-hosted service | [`docker-hardening.md`](docker-hardening.md) |
| **write** — where a fact lives, the tracking doc, archives, code comments | [`METHODE.md`](METHODE.md) |
| **act** — the gestures, in order, and who performs each | [`RUNBOOK.md`](RUNBOOK.md) |

> 🔴 **The section NUMBERS below are stable.** A section that moved keeps its number here as a one-line pointer, so *"standard §12"* written in an archive, a memory or a merged pull request **still resolves**. Renumbering would have silently falsified every archive — and an archive is immutable.

---

## 1. Basic concepts

Three things to distinguish clearly:

| Term | Definition | Location |
|---|---|---|
| **Working folder** | The physical directory holding everything (code, notes, secrets, logs) | `~/Documents/Claude/<project>/` |
| **Local Git repo** | The Git history stored in `.git/` + the tracked files | In `<project>/repo/.git/` |
| **GitHub repo** | Remote mirror of the local repo, pushed to github.com | GitHub server (`origin`) |

**Golden rule**:

> The GitHub repo contains **only what is needed to clone, build, and run the application**. Everything else — notes, plans, thinking, secrets, personal dev config — lives in the working folder, outside Git.

`.gitignore` is the operational boundary between the two.

**Language & tone rule**:
> All **versioned content (pushed to GitHub)** is written in **English** — code, **code comments**, `repo/` docs, `README.md`, `.env.example`. **Exception**: the project's `README.md` is in English (default) **and** French. Local/gitignored files (`workspace/`, `secrets.md`) can stay in French. ⚠️ **`CLAUDE.md` is versioned** *(§6)*, so it follows the English rule too.
> **Remaining exceptions**: the local file templates stay in French — `templates/repo/.envrc`, `templates/workspace/*`. *(`templates/repo/CLAUDE.md` left that list the day it stopped being a local file: it is committed in every generated project.)*
> They are gitignored in the generated project and never reach GitHub.
> **The bilingual `README.md` is a different kind of exception — deliberate, not a leftover**: it is the one **versioned** file allowed to carry French, in every project *(`README.md` here, `templates/repo/README.md` in each one generated)* — detail in §15.
> **Tone**: never **2nd person** (`you/your`, `vous/tu/ton`) in versioned content **or in the app UI** — write "the user" / "l'utilisateur" or impersonal phrasing.

---

## 2. Standard directory layout

```
~/Documents/Claude/<project>/             ← working folder (backed up to NAS)
│
├── repo/                                 ← Git root, Claude Code's cwd
│   │
│   ├── .git/                             (local Git history)
│   ├── .gitignore                        (versioned/ignored boundary)
│   │
│   ├── .env                              ← IGNORED — app deployment variables (runtime API keys)
│   ├── .env.example                      ← versioned — template with no values (app only, never the PAT)
│   ├── .envrc                            ← IGNORED — direnv: the repo's PAT (GITHUB_PAT) + loads .env; exposes GH_TOKEN
│   │
│   ├── .claude/                          ← IGNORED — personal dev config for Claude Code
│   │   └── settings.local.json
│   │
│   ├── CLAUDE.md                         ← the `@AGENTS.md` import, and nothing else (§6)
│   ├── README.md                         ← versioned — install/run/structure for humans
│   │
│   ├── backend/, frontend/, shared/      ← versioned — app code
│   ├── docker-compose.yaml               ← versioned — runtime orchestration
│   │
│   ├── data/                             ← IGNORED — runtime data (SQLite, caches)
│   ├── node_modules/                     ← IGNORED — installed dependencies
│   └── dist/, build/                     ← IGNORED — build artifacts
│
└── workspace/                            ← EVERYTHING personal — its OWN git repo, LOCAL
    │
    ├── .git/                             (local history — NO remote, never pushed)
    ├── .gitignore                        ← `secrets.md`
    │
    ├── README.md                         ← workspace index
    ├── secrets.md                        ← IGNORED — GitHub PAT, API keys, auth procedures
    │
    ├── docs/                             ← SUIVI.md · archives/ · thinking, ADRs
    ├── plans/                            ← phase 1 plan, phase 2 plan, roadmap
    └── notes/                            ← scratch, drafts, conversation captures
```

### **TWO git repos per project** — and only one goes on GitHub

| | `repo/` | `workspace/` |
|---|---|---|
| **Content** | the app: what's needed to clone, build, run | the memory: tracking, decisions, plans, archives |
| **Remote** | ✅ GitHub — **PRIVATE at creation**, public later and deliberately *(RUNBOOK §1, §4)* | ❌ **none — never pushed** |
| **Claude Code's cwd** | ✅ | — *(reached via `../workspace/`)* |
| **Off-site backup** | GitHub | the working folder's **NAS backup** |

**Why `workspace/` has its own git.** Without it, it is versioned **nowhere**: any deletion there is **irreversible**, and it's the project's memory that's lost. A `.gitignore` protects the repo folder — **it does not protect the folder**.

**Why it has NO remote.** *(a)* It carries what must never become public — private repo names, incidents, host addresses. *(b)* The day `repo/` goes public, there is **nothing to clean up**: the boundary was set on day 1. *(c)* Git has no "version without pushing" mode — it pushes **commits**, not folders. **Two repos is the only mechanism.**

> ⚠️ **`secrets.md` is gitignored in `workspace/`.** The repo has no remote *today* — but if it ever gained one, **the entire history would go out at once**. A secret never enters a git object. Accepted consequence: this file has **no** anti-deletion safety net — the secret's source of truth lives in `.envrc`, `secrets.md` is only the human-readable documentation of it.

---

## 3. Decision rule — where does a file go?

Three questions, in order:

1. **Is it needed to clone + build + run the app?**
   → Yes: `repo/` **and** versioned.
   → No: move to question 2.

2. **Is it consumed by the app or by Claude Code at runtime, technically?** (e.g. `.env`, `.claude/settings.local.json`, `data/`)
   → Yes: `repo/` but **ignored** (must physically be there but must not leak).
   → No: move to question 3.

3. **Is it docs, plans, notes, personal secrets?**
   → `workspace/` (outside the published repo — but **under git**, in its own local repo: §2).

### Concrete examples

| File / folder | Question 1 | Question 2 | Location |
|---|---|---|---|
| `backend/src/*.ts` | Yes | — | `repo/backend/src/` versioned |
| `docker-compose.yaml` | Yes | — | `repo/` versioned |
| `README.md` | Yes (install/run) | — | `repo/` versioned |
| `.env` | No | Yes (app runtime) | `repo/.env` ignored |
| `.envrc` | No | Yes (direnv → git/gh) | `repo/.envrc` ignored |
| `.claude/settings.local.json` | No | Yes (Claude Code) | `repo/.claude/` ignored |
| `CLAUDE.md` | No | Yes (Claude Code) | `repo/CLAUDE.md` — **versioned**, and reduced to the import (§6) |
| `node_modules/` | No | Yes (Node runtime) | `repo/node_modules/` ignored |
| `data/` (SQLite) | No | Yes (app runtime) | `repo/data/` ignored |
| Phase 2 plan | No | No | `workspace/plans/` |
| Architecture diagram | No | No | `workspace/docs/` |
| Thinking notes | No | No | `workspace/notes/` |
| GitHub PAT, auth procedures | No | No | `workspace/secrets.md` |

---

## 4. Secrets management

→ **[`secrets-and-auth.md`](secrets-and-auth.md)** — the two secret locations, why `.env` and `.envrc` are separate, and the duplication to avoid.

---

## 5. GitHub authentication

→ **[`secrets-and-auth.md`](secrets-and-auth.md)** — read/write separation, the public-RO PAT, the 1-repo write PAT and its permissions, the 90-day expiration, the mechanisms rejected, and the non-interactive shell.

---

## 6. `CLAUDE.md` — the file that makes the rules readable at all

→ **[`claude-code-setup.md`](claude-code-setup.md)** — why it is versioned, what it carries, and what it never carries.

---

## 7. `.claude/` — project-level Claude Code config

→ **[`claude-code-setup.md`](claude-code-setup.md)** — which files Claude Code reads there, and which must not be created.

---

## 8. Claude Code's persistent memory

→ **[`claude-code-setup.md`](claude-code-setup.md)** — where the memory lives, and the rename procedure that preserves it.

---

## 9. Typical `.gitignore`

```gitignore
# secrets & local config
.env
.env.local
.envrc
.claude/
# CLAUDE.md is NOT here: it is versioned, and carries only the @AGENTS.md import (§6).

# deps
node_modules/

# build artifacts
dist/
build/
.tsbuildinfo
.vite/

# runtime data
data/
*.db
*.db-journal
*.db-wal
*.db-shm

# misc
.DS_Store
*.log
*.bak
*.bak-*
```

**Keeping this file alive**: once a new type of personal file has been added, add it to `.gitignore` immediately.
An entry that matches no file is **not harmful** — for a path generated only inside Docker and never on the Mac (`dist/`), it is **defensive, and it stays**. What is worth pruning is the entry that no longer corresponds to anything at all: it costs nothing but muddies the reading. *(These two statements used to live in two sections, and read as a contradiction.)*

---

## 10. Creating, configuring, evolving a project → **the RUNBOOK**

**The complete procedure lives in `RUNBOOK.md`** — and **it alone is authoritative**: order of actions, **who performs them**, direct URLs, exact permissions, full commands.

**Do not duplicate it here.** Two copies of a procedure always diverge, and it's the one that isn't re-read that sends someone looking for a permission that no longer exists.

| The RUNBOOK covers | § |
|---|---|
| **Creating a project** *(the 3 questions · the 2 PATs · `direnv allow` · revocation)* | §1 |
| **Working day to day** *(feat → PR → green CI → merge)* | §2 |
| **Publishing a version** *(CHANGELOG → tag → Release + image)* | §3 |
| **Switching PRIVATE → PUBLIC** *(the most dangerous moment of the lifecycle)* | §4 |
| **Acquiring / removing a capability** on a live repo | §5 |
| **Maintenance** *(Dependabot, Renovate, alerts, PAT rotation)* | §6 |
| **What the assistant CANNOT do** *(and why)* | §7 |

> 🔴 **This document states the WHY; the RUNBOOK states the ORDER OF ACTIONS.**
> In case of a mismatch between the two: **the RUNBOOK is authoritative on procedure**, this document on **conventions** — and **the mismatch is a defect to fix**, not an arbitration to make in passing.

**A Claude Code skill drives it** *(`new-project`)*: it stops at every action the maintainer must perform, gives the exact URL and values, waits for confirmation, then verifies. See `workspace/archives/000--2026-07-conception/SKILLS.md`.

## 11. Classic pitfalls to avoid

→ **Removed.** Its thirteen entries all restated §4-§8, now owned by **[`secrets-and-auth.md`](secrets-and-auth.md)** and **[`claude-code-setup.md`](claude-code-setup.md)**; two more are held by **[`repo-controls.md`](repo-controls.md)** *(concurrent work)* and by §9 *(a `.gitignore` entry matching nothing)*.

*(The number is kept so a reference to "standard §11" still resolves.)*

---

## 12. Branching policy — **it depends on ONE capability, not on the archetype**

→ **[`repo-controls.md`](repo-controls.md)** — the three capabilities, the two flows, the branches, the promotion, and concurrent work.

---

## 13. Version pin in production

→ **[`repo-controls.md`](repo-controls.md)** — why prod pins a tag and never `:latest`, and why the ghcr package must be verified.

---

## 14. Docker hardening (deployment security)

→ **[`docker-hardening.md`](docker-hardening.md)** — the absolute rules, the hardened compose template, the key directives, and the pre-prod checks.

---

## 15. README — dual target: dev + showcase

`README.md` serves **two audiences at once**, without choosing:
- **the dev** who clones/forks/contributes — install, run, structure, contribution;
- **the showcase** — an honest page that makes the project appealing, without overselling.

Polished, concise, **zero fluff**. Bilingual **English then French**, separated by `---`.

> 🔴 **It may RESTATE a description another document owns — never a RULE.** A visitor does not clone: sending them to `AGENTS.md` to learn what a folder holds points at a file they will never open, so the showcase says it on the spot, and briefly. A constraint keeps its single owner — restated here, the showcase becomes a second source of rules, and the stale one gets read. Worked through on one case: what `../workspace/` holds is described in both, while the rule that it never gains a remote lives in `AGENTS.md` alone.

**Typical structure**:
- **Title** = `Name — subtitle that says what it is` (not just the name).
- **Hook** aimed at the user's real problem, honest (no hollow superlatives).
- **Disclaimer** up top (⚠️ blockquote) if the tool is third-party/unofficial or touches funds.
- **Screenshots** light + dark theme via `<picture>` + `prefers-color-scheme`; the other theme folded into `<details>`.
- **"Why this exists / Pourquoi"** before the *how*.
- Short sections: Quick start, Structure, License.
- **Tone**: factual, quantified, honest about limitations — and never 2nd person (§1).

Model: `templates/repo/README.md`.

## 16. Project lifecycle docs, and what a project ships

**The tracking doc is a PRINCIPLE, not a mandated file** → **[`METHODE.md`](METHODE.md)** — what a resume doc must carry, why the shipped gets purged, why `SUIVI.md` is a replaceable default, and why two tracking systems in parallel means none.

*(This subject used to live in two places, each naming the other as the source. It now has one owner.)*

### Structural decisions → `repo/docs/adr/`
**Versioned, immutable.** An ADR is not edited when the decision changes: **a new one is written that supersedes the old one**. What matters is preserving the **why** — which the code can't express.

### What is VERSIONED (in `repo/`), and why

| File | Role | Why it's versioned |
|---|---|---|
| **`AGENTS.md`** | Project instructions **for any agent**: commands, structure, branches, conventions, controls, do-not-touch | **A real standard** ([agents.md](https://agents.md), handed to the Linux Foundation in late 2025, read by 30+ agents: Cursor, Copilot, Gemini CLI…). **`CLAUDE.md` imports it via `@AGENTS.md`** and carries **nothing else** — a file that cannot hold anything personal is one nobody has to remember not to fill (§6) → **a single source, zero drift**. |
| **`CHANGELOG.md`** | What changed **for a user** — [Keep a Changelog](https://keepachangelog.com) format, [Semantic Versioning](https://semver.org/spec/v2.0.0.html), an **inline Release link** per version (`## [X.Y.Z](…/releases/tag/vX.Y.Z)`), and **one `###` of each type per version** — the format implies that last one without stating it, which is how six versions came to repeat one. **An entry starts with a present-tense verb, opens on the EFFECT and never on the file that changed, holds 300 characters, and ends with the pull request that delivered it** *(that reference is not counted in the 300)*. What must survive the cut is any **limit** of the new behaviour; the demonstration belongs to the pull request | **The Release is WRITTEN, and it is the one document here that is**: a short opening paragraph, the highlights, and two links — the version's entries and its commits. **It never repeats the changelog**, which it points at: measured 2026-08-14, carrying both ran to 10 606 characters for one version, and a list of pull-request titles in its place says less than a paragraph. The writing rules are not house style: the imperative and the single parenthesis of references are [Common Changelog](https://common-changelog.org/), the effect-first rule is Keep a Changelog's first principle — *"changelogs are for humans, not machines"* — since a reader may never have opened the source. ⚠️ **The earlier ceiling of 750 was calibrated on the corpus it was meant to reform**, which endorses the drift: a threshold comes from a reference or an objective, never from the average of what is being corrected. |
| **`docs/adr/`** | One entry per **structural** decision (stack, schema, boundary) — [Nygard](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions) format | Preserves the **why**, which the code never states. Worth it even solo (near-zero cost). **Immutable**: an outdated decision isn't edited, it's *superseded*. |

**Present from the FIRST commit** *(all created by `init-project.sh`)*: `LICENSE` · `README` *(dual target, §15)* · `SECURITY.md` *(private advisories)* · `CONTRIBUTING.md` · `CODE_OF_CONDUCT.md` · `.github/` *(CI, `renovate.json`, `ISSUE_TEMPLATE/` + `config.yml`, PR template)* · `.gitattributes` if a vendored library.

**Deliberately left out** (solo-project theater, verified): `llms.txt` (SEO fad, not a standard) · `SUPPORT.md` · `GOVERNANCE.md` · `CITATION.cff` · `ROADMAP.md` (the tracking doc covers it).

### What TRAVELS from the template, and the question that decides it

🔴 **Does the generated project need it to RUN?** That is the whole rule.
`check.sh`, `open-pr.sh`, `release-notes.sh`, `checks/` and `.githooks/` are **executed there**, so they travel. `configure-repo.sh` travels for the same reason: a project changes its own status, and setting the server up for that is the one gesture it cannot perform without the script.

**A document describing the tool that BUILDS is pointed at, never copied** — `METHODE.md`, this document, `RUNBOOK.md`. A copy in every project is a copy nothing updates, and a rule gone stale is read with the authority of a live one.
🔴 **A note travels when its SCRIPT travels** — the rule is the script, never a glob over file names. A tool that runs there without its note leaves its constraints to be re-derived, or written into the code as comments, which is what this whole arrangement avoids.
What travels beside it is what it takes to run that script on the spot: `docs/code/<name>.md` next to its check, `docs/server-config.md` next to `configure-repo.sh`, plus **one RUNBOOK link, pinned** to the version the project was born from — `main` would soon describe something the project never received.

### The LICENSE — a one-file decision, and the right moment to make it

**PolyForm Noncommercial 1.0.0** by default (`templates/repo/LICENSE`): attribution required, noncommercial use allowed, commercial use closed — **including partial use**. Year and holder are substituted by `init-project.sh`, nothing to fill in.
🔴 **It is NOT open source** *(the OSI definition forbids restricting the field of use)*, and GitHub displays it as **"Other"**. A repo aimed at professional users, or meant to be adopted widely, wants a permissive license instead — **swapping `LICENSE` is a one-file decision**, and the moment to make it is **before the first release, not after**.
**`LICENSE-MIT` stays whatever the project chooses**: the files inherited from the template are MIT, so a generated project never inherits a restriction from the tool that built it.
Before locking it in, check: ① no dependency nor vendored code under copyleft *(GPL/AGPL)* imposing something stricter · ② does this project have a commercial future, in which case noncommercial is the wrong default? · ③ when in doubt, ask the maintainer.

**Other defaults**: eng/fr i18n with a **separate dictionary** (never inline ternaries) + parity checked in CI.

## 17. GitHub repo configuration

→ **[`repo-controls.md`](repo-controls.md)** — CodeQL in default setup, the recommended controls, scriptable vs UI.
→ **[`security-and-updates.md`](security-and-updates.md)** — who updates dependencies and pinned tools.

---

## 18. Control matrix — what, where, when, by whom

→ **[`repo-controls.md`](repo-controls.md)** — the matrix stage by stage, the private phase and its hole, the public flip, acquiring a capability.

---

## 19. One-sentence summary

> **One folder to back up** (`~/Documents/Claude/<project>/`), **two subfolders**: `repo/` for what goes on GitHub, `workspace/` for everything else. **One source of truth** per secret type. **Zero SSH** — reads via `gh` with a public-RO PAT, writes via a **1-repo** fine-grained PAT exposed by direnv (remote as a bare URL). **Branch + PR for infra changes**, versioned pin in prod. **With several people: one isolated working tree per person** (worktree or clone), branch protection on `main`.
