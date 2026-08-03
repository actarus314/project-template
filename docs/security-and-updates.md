# Security & update process

> Reference. This document **owns** one subject: **what moves in a repo, who decides it moves, and what checks it on the way in.**
> The principle: **always up to date, but through reviewed actions** — never silent drift, never day-zero adoption.
> *(What verifies the code, and where: `repo-controls.md`.)*

Three distinct channels bump versions; six tools check the code on every PR.
**A single update bot — Renovate — auto-detects everything** that needs bumping, with no list to maintain.

**Actor legend:** system / pin · automatic · human action · gap / manual.

---

## Who updates dependencies and pinned tools — Renovate, the sole auto-detecting bot

**The pin protects against supply chain attacks AND rots detection.** Both are true at once: a frozen `gitleaks` misses new secret formats, a frozen `semgrep` never gets new rules. **A frozen security scanner eventually misses what it's supposed to find.** Hence a bot that bumps — but which one, and over what scope?

**Renovate is the ONLY update bot, and it AUTO-DETECTS everything.** It discovers every ecosystem from the repo's manifests *(npm, pip, docker, actions, gradle, cargo, go, conan…)* **with no list to maintain**, and can ALSO read a `curl`-ed binary inside a `run:` — something Dependabot cannot do. That's what makes the scope **universal**: a language added tomorrow is covered **without touching the template**. Dependabot, on the other hand, requires declaring every `package-ecosystem` **by hand** *(no auto-discovery — the opposite of CodeQL)*: keeping it as the update bot meant a manual list rotting silently. **So it was removed from the update role.**

> **But its ALERTS stay.** Dependabot's CVE detection *(native, free even in private)* keeps running; **Renovate READS it** *(`vulnerabilityAlerts`)* to open its remediation PRs. What changed is *who opens the PR*, not *who detects*. `configure-repo.sh` leaves **alerts** on everywhere: it's the **dependency graph** that Renovate reads *(without it, its security path would be empty, silently)*.

**Security updates, however, depend on the number of stages** — because their PRs **always target the default branch**, and `target-branch` only redirects *version* updates.

| | Dependabot security updates | Why |
|---|---|---|
| **2 stages** *(`main` only)* | **ON** — the safety net | The default target **is** the right branch. Overlap with Renovate's security PRs = tolerated noise; a silent hole = not tolerated. Transitional: moves to `disabled` **once a Renovate security PR has been observed on a private repo**. |
| **3 stages** *(`develop` exists)* | **OFF** | Its PR would enter through `main`, **bypassing staging** — exactly what the 3 stages exist to prevent. Renovate, on the other hand, knows how to target `develop` *(`baseBranchPatterns`)*. The safety net can't play its role here: all that's left is the bypass. |

> ⚠️ **The removal is conditioned on proof that Renovate is alive** — its *Dependency Dashboard* updated less than 14 days ago *(two weekly-schedule cycles)*. **A dashboard existing proves nothing**: a `disabled` repo keeps its own *(lived through it — 6 days of dead bots)*. Without the proof, `configure-repo.sh` **keeps** Dependabot and **says so**: pulling the safety net while betting on a dead bot is the July outage.

| What | How Renovate bumps it |
|---|---|
| `uses:` (actions) · npm · docker (`FROM`) · pip *(`requirements-ci.txt` → zizmor, semgrep)* · any other manifest | **auto-detected native manager** — no declaration |
| `gitleaks` · `actionlint` · `osv-scanner` · `trivy` *(binaries pinned by VERSION + SHA256 inside a `run:`)* | **`customManagers` regex** — `github-release-attachments` datasource: bumps **version AND checksum in the same PR** |

> 🟢 **No `enabledManagers`: Renovate auto-detects EVERY manager.** *(Removed at the full-Renovate switch — it was the opposite as long as Dependabot handled version updates, to avoid duplicate PRs. Without `dependabot.yml`, duplicate version-update PRs can no longer happen.)* The `customManagers` cover the 4 extra binaries; they run regardless.

**Update policy** *(stay current, but through reviewed actions)*: routine version = **PR reviewed by a human** (`automerge` false at the top level); **SECURITY = auto-merge** (`vulnerabilityAlerts.automerge`). Security PRs **natively bypass `minimumReleaseAge`** — the 3-day anti-compromised-release delay stays on routine updates, **never** on a CVE fix.

**Safety net**: a wrong checksum makes `sha256sum -c` fail **in CI** — loudly, never silently. A red PR gets closed; it cannot poison `main`.

**Prerequisite**: the **Renovate** app must be installed on the repo *(GitHub UI, free)*. Without it, `renovate.json` is **inert**. As a fallback, self-hosting `renovatebot/github-action` *(AGPL-3.0, free forever)* runs the same config — at the cost of a **classic `repo`-scoped PAT** *(fine-grained ones don't work with Renovate)*.

---

## The flow — three version-bump channels

Each channel has its trigger, its delay, its gate (the CI) and its decider at merge time.
They diverge at the key moment: **version → a human merges**, **security → auto-merge**.

### Channel 1 — code dependency

*Triggered by hand · decided by hand · impact: the app.*

1. **Dev · local** — bump a dep: `npm install x@2` during development.
2. **Automatic** — lockfile written: exact version **+ integrity hash** in `package-lock.json`.
3. **Git** — push: the lockfile goes to GitHub.
4. **CI** — scan: `npm ci` + osv on the lockfile's **exact** versions.
5. **Impact** — `local == CI` guaranteed: both read the same lockfile → no loop.

### Channel 2 — Renovate · version update (routine)

*Triggered by the bot · decided by a human · impact: deps + tooling.*

1. **Renovate · scheduled** — Monday: auto-detects every ecosystem (npm, docker, actions, pip, gradle, cargo…) **+** the 4 pinned binaries, and proposes a bump.
2. **Delay** — 3-day maturation: the release must age — long enough for a poisoned one to be spotted.
3. **Renovate** — PR opened: minor/patch grouped, majors isolated.
4. **CI** — gate: green? a breaking bump stays red, here.
5. **Human · the maintainer** — reviewed merge: every update gets seen go by — no auto-merge on routine.
6. **Impact** — the pin moves forward: `main` + local realign on `pull`.

### Channel 3 — Renovate · security update

*Triggered by a CVE alert · decided by policy · impact: closes a flaw.*

1. **Alert** — CVE published: the **Dependabot alerts** (native detection, free even on private) raise it.
2. **Renovate** — security PR: Renovate **reads the alert** (`vulnerabilityAlerts`) and opens the fix. **No delay** — security natively bypasses the 3-day maturation.
3. **CI** — gate: green?
4. **Auto** — auto-merge (`vulnerabilityAlerts.automerge`): the only exception to human action.
5. **Impact** — flaw closed: without waiting for the next session.

### Ongoing — detection & scan data

The **Dependabot alerts** (CVE detection, native, free even on private) run in the background — they're what Renovate reads for channel 3. In parallel, the **OSV database** (advisories) and the **semgrep packs** `p/…` are pulled **on every** CI run, with no PR — already always up to date. We pin the **engine** (for `local == CI`), not the **data** we want fresh. An unknown flaw stays a zero-day: no scanner catches it, pinned or not.

> **Safety net** — a bump that introduces a finding fails **its own PR**. CI red → no merge → `main` is never broken for the team.

---

## The checks — what the CI runs on every PR

Each tool **auto-detects its own scope** and tracks the code's drift with no human memory needed (the CodeQL model). Since the switch to full-Renovate, even updates follow this rule: Renovate auto-detects the ecosystems, there is no more list of ecosystems to maintain by hand.

| Tool | What it looks at | Detection | What it catches |
|---|---|---|---|
| `CodeQL` | languages present | auto | code flaws — *the model* |
| `gitleaks` | the full git history | auto | committed secrets |
| `actionlint` | `.github/workflows/` | auto | workflow errors |
| `zizmor` | `.github/workflows/` | auto | workflow security (pin policy) |
| `semgrep` | the code · curated packs | quasi-auto | security anti-patterns (private phase) |
| `osv-scanner` | **all** manifests `-r .` *(excluding CI tooling)* | auto ✓ | vulnerable deps (blocks the PR) |
| `Dependabot alerts` | installed deps | auto (native) | CVE detection → **read by Renovate** |
| `Renovate` | **all** manifests **+** 4 binaries | auto ✓ | deps + tools to bump (version + security) |

---

## The decisions — who decided what, and why

The thread of this effort, frozen for pickup later.

- **Full-Renovate** *(the maintainer — ratified 2026-07-20)* — a single update bot that auto-detects everything from the manifests, C++ included. Dependabot removed from the update role (it required a manual list per ecosystem); its **alerts** stay (detection), Renovate reads them. Empirical proof: 8/8 managers detected with no declaration.
- **Keep the pin** *(the maintainer)* — it's not "staying old": it's what guarantees `local == github`. Without it, everyone grabs "latest" at a different moment → an endless loop.
- **Version = human action** *(the maintainer)* — see the updates go by. A 6-month project would otherwise get dozens of invisible bumps.
- **Security = auto** *(the maintainer)* — the only exception to human review: a CVE fix must land fast. Declarative auto-merge (`vulnerabilityAlerts.automerge`), which natively bypasses the maturation delay.
- **3-day maturation** *(the maintainer)* — `SHA256` only protects the transport, not a **poisoned** release. The delay lets the community spot it. Applies to routine, never to a security fix.
- **semgrep as-is** *(analysis)* — `--config auto` would turn telemetry back on and make the rules unpredictable, with no security gain. We keep the curated packs + `--metrics=off`.
- **osv `scan -r .`** *(analysis + the maintainer)* — the scope follows the code instead of being hardwired to npm; a local test proved **7 Python CVEs** were missed.
- **CI tooling out of osv's scope** *(analysis + the maintainer — 2026-07-21)* — `requirements-ci.txt` (semgrep, zizmor) is gitignored **+** `git add -f`: osv respects the `.gitignore` patterns, so it doesn't resolve the transitive graph of dev tools **never shipped** — pure noise (CVEs from `python-multipart`, `mcp`…), not the product's attack surface. Renovate indexes **tracked** files, not the `.gitignore`: it keeps bumping them. Proven both ways. The full *why* lives in the `.gitignore`.

---

## What's left to build

The **universal build/test stub**: the security checks are already language-agnostic — only build/test remains to be filled in, per language.
