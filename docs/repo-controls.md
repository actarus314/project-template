# Repo controls — from commit to production

> Reference. This document **owns** four subjects: the **branching policy**, the **version pin in production**, the **GitHub repo configuration**, and the **control matrix** — what verifies the code, where, when, and by whom.
> **The "Private" column is the key**: a private repo on the Free plan has **no ruleset**.
> The controls run, but **nothing requires them** — a red PR can be merged.

<!-- Table of contents. GitHub renders its own from the headings; this one is for whoever
     reads the file from disk, where nothing generates it. `verify-links.sh` checks that every
     anchor below resolves to a real heading, so it cannot quietly go stale. -->
## Contents

- [The flow — where the code goes](#the-flow-where-the-code-goes)
- [Version pin in production](#version-pin-in-production)
- [What to enable, and where](#what-to-enable-and-where)
- [Every control, in one table](#every-control-in-one-table)
  - [What is merely SET on the server](#what-is-merely-set-on-the-server)
  - [The GATE — one line, and it is the same one everywhere](#the-gate-one-line-and-it-is-the-same-one-everywhere)
  - [The THREE RHYTHMS — what triggers each, and what each costs](#the-three-rhythms-what-triggers-each-and-what-each-costs)
- [GitHub repo configuration](#github-repo-configuration)
- [The control matrix — what, where, when, by whom](#the-control-matrix-what-where-when-by-whom)
- [The private → public switch — a normal step in the flow, not a special case](#the-private-public-switch-a-normal-step-in-the-flow-not-a-special-case)
- [Acquiring a CAPABILITY on an already-live repo](#acquiring-a-capability-on-an-already-live-repo)

---

## The flow — where the code goes

**The single principle: `main` is production.**
We **never** write to it directly — the only way in is a **pull request with green CI**.
Everything else follows from that.

> ### What decides the flow: *a single question*
> **"Is there a host to VALIDATE before production?"** — that's the **`staging`** capability, and only that one.
> **Not the language, not Docker.**
> A `node` project with no host to validate does **not** need `develop`. A Pages site packaged as an image **doesn't either** — the image *is* the page, served by nginx directly.
> Publishing an **artefact** (tag → ghcr image) is an **independent** capability: it attaches to **both** flows below.

> Branching policy depends on **three independent capabilities**, not on a fixed archetype: reducing the choice to `static`/`node` collapses three distinct questions into one and breaks as soon as the standard case is left behind *(cf. DORA · Fowler · ThoughtWorks Radar)*.

### The 3 CAPABILITIES — independent, composable

`--type` now only decides the **TOOLCHAIN** (which `ci.yml`: `static` = no npm · `node` = npm/tests/types). Everything else follows from **three questions that have nothing to do with each other**:

| Capability | The question to ask | What it triggers |
|---|---|---|
| **`--pages`** | Is the site served by **GitHub Pages**? | `pages.yml` |
| **`--artefact`** | Does the repo **publish an image that someone ELSE deploys**? *(self-hosters, NUCs…)* | `docker-publish.yml` (**`build-check` + Trivy**) · **tag ruleset** · **immutable releases** · **PUBLIC ghcr package** *(the base image is bumped by Renovate, auto-detected — nothing to declare)* |
| **`--staging`** | Is there a **host to VALIDATE** before prod? | **`develop`** branch · `develop` ruleset · merge commit onto `main` · **3-stage flow** |

> 🔴 **`develop` does NOT follow from Docker — it follows from STAGING** — the single question and both examples: [above](#the-flow-where-the-code-goes).

**The need for a staging stage comes from DEPLOYMENT, not from the language or taste.**

### The real combinations

| Case | `--type` | pages | artefact | staging | Flow |
|---|---|---|---|---|---|
| Pages site *(shortcut `--type static`)* | static | ✅ | — | — | **GitHub Flow** — `main` + `feat/` |
| **Pages site + Docker** *(third parties self-host it)* | static | ✅ | ✅ | — | **GitHub Flow** + `v*` tag → image |
| Page hosted **outside** Pages | static | — | ✅ | depends | depends on staging |
| Docker app → NUC *(shortcut `--type node`)* | node | — | ✅ | ✅ | **3 stages** — `feat/` → `develop` → `main` + tag |
| Node project **without** staging | node | — | ✅ | — | **GitHub Flow** + tag |
| **Other toolchain** *(Android/Kotlin, C/C++, Rust, Go…)* | generic | — | — | — | **GitHub Flow** — security controls only, build/test left to fill in |

**Backward-compatible shortcuts**: `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging` · `--type generic` ≡ **no capability** *(opt-in via flag)*. As soon as a capability is passed explicitly, it **composes** (`--no-staging` removes it from the shortcut).

> **`--type generic`** *(universality)*: the toolchain the template doesn't pre-wire. It ships the **security controls** *(language-agnostic: gitleaks, actionlint, zizmor, semgrep, osv `-r .`, + CodeQL when public, + Trivy if `--artefact`)* and a **commented build/test stub** to fill in. An Android or C++ project is thus **secured from day 1**; only the language's `./gradlew`/`cmake`/`cargo` needs adding. ⚠️ osv reminder: it's **lockfile**-oriented — for Gradle, enable dependency-locking *(`gradle.lockfile`)*, otherwise deps aren't scanned.

⚠️ **`init-project.sh` REFUSES `--staging` on a Pages site without an artefact** — why: [Without `staging`](#without-staging-github-flow-two-branches-are-enough) below.

**The triple filter catches this kind of regression before it reaches prod** (cf. "Why 3 stages" below) — but only where a host to validate exists. Elsewhere, it would have filtered nothing.

**Git Flow is dead**: `nvie/gitflow` was **archived by its author on 2025-10-14**. Do not bring it back.

### Without `staging` — GitHub Flow, two branches are enough

This is the case of a Pages site *(Pages **is** already prod, so there is nothing to validate upstream)*, **and also** that of a static site packaged as an image so third parties can self-host it.
Nothing to validate upstream → a `develop` would be an **empty ritual**, and a long-lived branch nobody uses drifts until the merge stops happening.

```
main     ●──────────────────●──────────────●────◆
                            ▲               │    └─ tag v* → image ghcr   (capability `artefact`)
                       PR · CI green        └────── merge → Pages = PROD  (capability `pages`)
                            │
feat/…   ●────●────●────────┘
         commits (gitleaks hook on each one)
```

> The two outputs are **optional and independent**: a repo can have only Pages, only the image, or **both** (this is the case of a static site, once dockerized).

| # | Step | Command |
|---|---|---|
| 1 | Branch off `main` | `git switch -c feat/<topic>` |
| 2 | Commit — the hook refuses a secret | `git commit` |
| 3 | Open the PR — **the CI runs before the code touches `main`** | `gh pr create --fill` |
| 4 | Merge **only if the CI is green** | `gh run list --commit "$(gh pr view <n> --json headRefOid --jq .headRefOid)"` then `gh pr merge --squash` *(**not** `gh pr checks`: the `Checks` permission cannot be granted — "The control matrix", below)* |

### With `staging` — three tiers, because there's a host to validate

`develop` earns its place: there's a **real host** to validate before production.
And prod doesn't follow a *branch*, it follows a **pinned tag** — we promote an **artefact**, not a branch.

```
main     ●───────────────────────────●────◆   tag v1.2.3 → image ghcr → PROD
                                     ▲
                                PR · CI green  (release)
                                     │
develop  ●────●────●────●────────────┘   staging — deployed on a real host, validated
              ▲
         PR · CI green
              │
feat/…   ●────┘
```

> ### This is NOT two pull requests per change
> That's the classic confusion, and it would make the flow unbearable.
> **The `feat/` branches pile up in `develop`** — one PR each, that's the normal pace of work.
> `develop → main` happens **only when publishing a version**: **a single PR for N changes**.
> Solo, that's roughly once a week, not once per commit.

> ### Why the pull request even solo, even in private
> Without a PR, we push to `main` and the CI runs **after**: it becomes an **autopsy**, not a barrier.
> It records the damage on the branch we just declared "production".
> With a PR, it runs **before** — that's the whole difference between **knowing** and **preventing**.
>
> **This has already happened**: a direct push to `main` removed a `user:` directive — the image
> shipped as `:latest`, the prod host pulled it, and production went down, discovered only afterward.

### Why `develop` is NOT the anti-pattern it gets accused of being — the nuance is structural

*Environment branches* (one branch per environment) are a documented anti-pattern: Fowler ("*soon leads to a world of misery*"), ThoughtWorks (*environmental drift*). **But the criterion isn't the branch's name — it's what drives the deployment.**

> ✅ **This standard is on the right side**: prod never follows a branch, it follows a **pinned tag** (`APP_IMAGE_TAG=X.Y.Z`, "Version pin in production" below). An **artefact** is promoted, not a branch — exactly the alternative DORA and ThoughtWorks recommend *instead of* environment branches.
>
> ❌ **The switch happens** the day `develop` grows long-lived (code diverges by environment) or a host does `git checkout develop` as its deployment's source of truth.
>
> **Rule that follows**: **`develop` stays short-lived** — merged in **days**, not weeks. That's the only condition to uphold.

### Branches

- **`main`**: prod. Protected (ruleset). With the **`artefact`** capability, prod runs on a **pinned tag**, never on the branch.
- **`develop`** *(**`staging`** capability only — **NOT** "node", **NOT** "Docker")*: staging. Protected. **Short-lived.**
- **`feat/<topic>`**: from `develop` **if `staging`**, otherwise from `main`. Deleted on merge (auto).
- **`v*` tags**: **immutable** — a ruleset forbids their deletion and their being moved. Without that, the version pin below guarantees nothing *(cf. "Recommended controls")*.
  🔴 **That immutability is why the tag is the SINGLE SOURCE of the version** — and not a `VERSION` file, a CHANGELOG heading or a manifest, all of which can be rewritten in any pull request. Everything able to read it does so *(`--version` derives it from `git describe`)*; the places that must carry a copy — the CHANGELOG, a plugin manifest — are compared against it by a guard, because a copy nobody watches is a copy that drifts.
  ⚠️ **A tag is pushed AFTER the settings are in place, never before**: immutable releases are **not retroactive**, so a release published earlier stays unprotected forever.

### Full flow

Three stages: `feat/` validated **locally** → merged `--no-ff` into `develop`, validated on the **staging host** → `develop → main` PR merged **as a merge commit** (never squash — that preserves `feat/*` commit history and avoids making `develop` diverge) → `vX.Y.Z` tag pushed to `main`, triggering the release CI. **Exact commands, in order: RUNBOOK §2-3.**

> ⚠️ **A consequence of that merge commit: `develop` reads as "N commits behind `main`" — permanently, and that is CORRECT.**
> The promotion's merge commit is created **on `main` only**; `develop` never receives it. The gap therefore grows by one **at every cycle**, and **`0 0` is unreachable by construction**. GitHub's *"N commits behind"* banner measures **graph topology**, not content.
>
> 🔴 **One measure decides, and it is the content:**
> ```bash
> git diff origin/main origin/develop     # EMPTY = nothing to do, whatever the commit count says
> ```
> **Empty** — there is nothing to realign, and a `feat/` branch cut from `develop` starts from the right code. **Non-empty** is the real defect *(typically a `develop` recreated from a point before the release: an older CHANGELOG and version)*, and only that case is worth repairing.
>
> ⚠️ **Never "fix" the count**, because every way of doing so is worse than the gap: squashing the promotion makes the branches diverge for real *(above)*, and a squashed back-merge lands a **differently-SHA'd** commit on `develop`, creating the divergence it claimed to remove. A fast-forward is possible only where nothing protects `develop` — in **public** its ruleset requires a pull request.

> 🔴 **In PRIVATE, shipping to production USED TO DESTROY the staging branch.**
> ✅ **Fixed at the root**: on a **private**, 3-stage repo, `configure-repo.sh` **no longer sets** `delete-branch-on-merge` — `feat/*` branches are deleted by hand, the staging branch survives. Going public restores it *(rerunning the script)*. ⚠️ **A repo configured before this fix still carries it.**
> `delete-branch-on-merge` deletes the **source** branch of **any** merged PR — so **`develop`**, when the `develop → main` PR merges. **In public**, the `develop` ruleset (`deletion` rule) refuses this; **in private, no ruleset exists** *(see "The control matrix", below)* and the branch disappears **silently**.
> **And the damage cascades**: on the next rerun, `configure-repo.sh` no longer sees `develop`, concludes "no staging", **doesn't set its ruleset**, and **puts `main` back to squash-only** — but **squashing `develop` into `main` makes the two branches diverge on every cycle**. The next promotion becomes **impossible**. *Shipping successfully breaks the next cycle.*
> **→ Recreate `develop` immediately after promotion:** `git switch -c develop main && git push -u origin develop`
> *(The script now detects it: it compares what the repo **publishes** — the `## Branching` block of `CONTRIBUTING.md` — against what **exists**.)*

For trivial changes (doc typo, variable rename, query fix with no runtime impact) on a solo project: pushing directly to main remains acceptable.

### Concurrent work — several sessions / people

> The flow above assumes **one working tree per person**. The pitfall isn't Git but **sharing the same working folder** — the typical case: two Claude Code sessions launched against the same `repo/`.

**What's shared per folder** (hence dangerous with several people in the same place): `HEAD` (current branch), the `index` (staging area), and the files on disk. Consequences:

- a `git checkout -b` switches **the other person's** branch without warning;
- simultaneous edits of the same file → last writer wins (silent loss);
- `git add` can sweep up the other person's uncommitted work;
- telltale symptom: `gh pr merge --delete-branch` → *"'main' is already checked out at …"* (the remote merge still succeeds, only the local branch deletion fails → delete the remote branch by hand).

**Rule: one isolated working tree per person.** Two options:

| Option | When | Command |
|---|---|---|
| **Separate clones** | different people/machines | `git clone` each on their own side |
| **`git worktree`** | same machine, several sessions/tasks | `git worktree add -b <branch> /path/iso origin/main` … `git worktree remove <path>` |

The worktree shares `.git` (objects, branches, remotes) but has its **own folder and its own `HEAD`**.
Editing, committing, pushing, opening a PR — **without ever touching the other tree**.
**Deploying** from a worktree without poisoning the main folder's `./data`: `docker build` **from the worktree** (the image is *baked*), then `docker compose up -d` **from the main folder** (that's where the real volumes are).
Cleanup: `git worktree remove <path>` + delete the branch.

**Discipline once trees are isolated:**

- `git fetch` + rebase/pull **before** every push (always push on top of the up-to-date remote state → no non-fast-forward);
- **never `--force`** on a shared branch (`--force-with-lease` if truly necessary);
- **targeted** `git add` (never a blind `git add -A` in a shared tree).

**Server-side safety net — branch protection on `main` (and `develop`)**: turns discipline into an enforced rule. PR required (no direct push), **green CI required** (`npm test` + `typecheck`), force-push and branch deletion forbidden, linear history. This is the most effective net against collisions on the remote.

**Deployment / shared state outside Git.**
Only one person rebuilds/deploys `main` HEAD at a time.
And **never mutate shared state outside Git while a service is running.**
Example: opening a SQLite file **in WAL mode from the host** while the container is using it breaks the `-shm` mmap on virtiofs (Docker Desktop macOS) → `disk I/O error` (data intact; fix: `docker restart`).
To inspect a database: go through the API or `docker exec` — **never** a direct connection from the Mac.

### Why 3 stages

A push **directly to `main`** can introduce a configuration regression (e.g. a `docker-compose` directive removed by mistake, incompatible with the runtime image's constraints — enforced non-root UID, volume permissions, etc.) that **no build detects**: the code compiles, the image builds, only **real-world behavior** reveals it. Without an intermediate stage, this kind of bug reaches `main`, then `:latest`, and a prod host can **pull it before anyone notices**. The triple filter (Mac → NUC/`develop` → NUC/`main`) catches this kind of regression **before** it reaches prod — potentially twice.

### Build vs pull of an image

For stages 1 and 2, a **local build** on the target host (`docker compose up --build`) is enough. It's tempting to extend the GHA pipeline to publish `:branch-feat-…` or `:develop` images consumable via `docker compose pull` — only do this if:
- several hosts must share exactly the same artefact (e.g. multi-NUC);
- the target host lacks the build toolchain;
- the local build is too slow on the host (older arm64 clusters).

For a solo Mac+NUC project, local build is the short path. The CI workflow only serves prod (versioned tag + `:latest`).

### When to skip a stage

- **Hotfix patch**: create a `fix/<topic>` from `main`, validate locally, merge directly into `main`, patch tag (`vX.Y.Z+1`). Skip staging if urgency justifies it AND the regression is very narrow.
- **Documentation** or **rename** with no runtime impact: commit directly to `main`.
- **DB migration** or **Dockerfile/compose change**: **never** skip staging. The rule.

### Where we do NOT tighten the screws — *too many controls kills the control*

- **No lint at pre-commit** — no linter is universal across the three toolchains; enforcing one would fail the hook on the very first commit.
- **Only one blocking control locally: secrets.** Vital, instant, and **irreversible once pushed** — the three criteria that justify blocking. Everything else waits for the CI, where waiting costs nothing.
- **Zero mandatory review** (`required_approving_review_count = 0`): solo, self-approving would be theater.

---

## Version pin in production

> ⚠️ **The ghcr package CAN be private — even on a public repo. This gets VERIFIED, never assumed.**
> **PERSONAL account**: a package published from a **public** repo inherits its access → **pullable right away**, no action needed.
> **ORGANIZATION**: it can be **PRIVATE** *(org default)* → the host's `docker compose pull` gets **403**, and the pin below is useless: **there is nothing to pull**.
> → **`configure-repo.sh` queries the registry ANONYMOUSLY**, exactly like the prod host would, and only asks for the manual step **if the pull fails** *(exact UI path: "Setup — scriptable vs UI", row "ghcr package visibility", below)*. *A green "Publish image" job proves NOTHING.*

On production hosts (NUC, deployed servers), **pin the image tag** in the host's `.env`:

```
APP_IMAGE_TAG=1.1.0
```

Never `:latest` in prod. The point: a deployment must require an explicit `git tag`, not have a push to `main` automatically propagate.

On dev hosts (local Mac): `:latest` or no pin at all is fine.

### Why

`:latest` is a mutable tag that follows the `main` branch. Without a pin, a WIP push to main → release workflow → `:latest` updated → prod-side `docker compose pull` can bring in unreviewed code. With a versioned pin, prod is frozen and an upgrade requires a conscious human action (changing the tag).

---

## What to enable, and where

### Baseline — EVERY repo, no exception

| Control | Setting | When |
|---|---|---|
| **`gitleaks`** | **`pre-commit` hook** (staged files) **+ CI on the FULL history**. **Never optional**: it's the **only** anti-secret net during the whole private phase (no server-side secret scanning on Free). Pinned binary + checksum — **not** `gitleaks-action`, which requires a **license** on an ORG repo. | commit + every PR |
| **`semgrep`** | static analysis of **application code** (`p/security-audit`, `p/owasp-top-ten`, `--exclude=.github`). Exists because **CodeQL is unavailable on private** — it **precedes** it, doesn't replace it (file-by-file analysis). | every PR |
| **`osv-scanner`** | vulnerable dependencies (all manifests, `-r .`, OSV database). **The equivalent of `dependency-review`, which does work on private.** | every PR |
| **`actionlint` + `zizmor`** | workflows are code: a `${{ }}` in a `run:` is a **shell injection**. | every PR |
| **CodeQL** | native **default setup**, enabled by `configure-repo.sh` (`PATCH /code-scanning/default-setup`, `Administration: write`). **Detects languages and KEEPS THEM UP TO DATE on its own** — the previous `codeql.yml` declared only ONE, and missed `actions` workflows *(see "CodeQL: default setup", below)*. **Unavailable on private** (GHAS) → arrives at the flip. The two modes are **mutually exclusive**. | push/PR `main` + weekly |
| **Dependabot alerts** | **CVE detection** — native, free even on private, **everywhere**: it's the dependency graph that Renovate reads. Version updates → **Renovate**. **Security updates**, though, are only the safety net **at 2 stages** — at 3 stages their PRs would target `main` and bypass staging *(→ `security-and-updates.md`)*. | continuous |
| **Renovate** | **only update bot.** Auto-detects **all** the repo's ecosystems (npm, docker, actions, pip…) **with no declaration at all**, + the 4 pinned VERSION+SHA256 binaries (gitleaks, actionlint, osv-scanner, trivy). Reads Dependabot alerts (`vulnerabilityAlerts`) for its security PRs. Routine = PR reviewed by a **human**; **security = auto-merge**. Minor/patch grouped. | continuous / weekly |
| **Secret scanning + push protection** | native, free on **public** (unavailable on private/Free). | every push |
| **`main` ruleset** | PR required · required checks (**`checks`** + CodeQL + **`build-check` if `artefact` capability**) · no force-push/delete · no bypass · `required_approving_review_count = 0` (solo). | continuous |
| **`tags` ruleset + immutable releases** | a `v*` tag that can be neither moved nor deleted, non-replaceable assets. **Without both, the prod pin above is worth NOTHING.** | continuous |
| **Third-party actions** | **full SHA** (`# vX.Y.Z` as a comment) ; `actions/*` and `github/*`: major tag tolerated. | — |
| **`permissions:` workflows** | minimal: `{}` deny-all + write scoped **per job** · `persist-credentials: false` on every `checkout`. | — |

### In addition — `node` TOOLCHAIN

| Control | Setting |
|---|---|
| `npm audit --audit-level=high --omit=dev` · `npm test` · `npm run typecheck` | PR gate. |

*(npm **and** docker updates are no longer per-toolchain lines: Renovate auto-detects them — see the **Renovate** line of the baseline.)*

### In addition — `artefact` CAPABILITY *(⚠️ NOT "node": a static site can publish an image)*

| Control | Setting |
|---|---|
| **Trivy as PR gate** | **`build-check`** job of `docker-publish.yml`: build (`load: true`) then `trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1`. **Pinned binary + checksum.** `configure-repo.sh` makes it a **REQUIRED** check — *a scan that isn't required blocks nothing.* |
| **Docker hardening** | base image pinned by SHA256 **digest** · runtime **with no package manager** (`docker-hardening.md`) · `tmpfs` `noexec,nosuid,nodev,size=` · healthcheck · `:latest` blocked on pre-release. |
| **PUBLIC ghcr package** | 🔴 Default depends on the **owner**: **personal** account → pullable anonymously (**HTTP 200**) ; **organization** → private by default (**403**), no one can self-host. `configure-repo.sh` **tests the anonymous pull** and only asks for the action if the test fails. **Detail, test provenance, UI procedure: "Setup — scriptable vs UI", row "ghcr package visibility", below.** |

### In addition — `staging` CAPABILITY

| Control | Setting |
|---|---|
| **`develop` ruleset** | the requirements of `main`, **minus two, by design**: ❌ no `code_scanning` *(CodeQL only analyzes `main` — requiring it here would block every PR on a check that will never arrive)* · ❌ **squash ONLY** *(the merge commit is reserved for `main`, for promotions)*. |
| **Merge commit allowed on `main`** | squash only is **incompatible** with a staging branch. |
| **Back-merge `main` → `develop`** | consequence of the two lines above: the only route is a **squashed PR** *(a direct push runs into the `pull_request` rule, a merge commit into squash-only)*. ⚠️ **GitHub's message names the wrong culprit** — *"Merge commits are not allowed on this repository"* is shown even though the repo allows them *(`allow_merge_commit=true`)*: it's the **rule** that blocks, not the repo's setting. Looking in the settings is a dead end. |

> **Plan note**: on a personal account (non-org), public secret scanning only has the **default patterns** — no custom regex nor validity checks (reserved for GitHub Secret Protection, paid/org). Hence the value of gitleaks for non-standard secrets.

---

## Every control, in one table

**One table, so a dissonance shows.** These used to be five — the development machine, two CI
sections, the server, and the house checks — and the same control appeared in two of them with
different wording. Anything that RUNS is below; what is merely *set* on the server, and so has
neither a duration nor a trigger, is in the short table after it.

**Reading the columns.** *Looks for* is the defect, not the mechanism. *Where* is the machine that
runs it. *Travels* says whether a generated project gets it. *Blocks* separates what stops a merge
from what only draws a list. *Maturity* is the one thing no measurement gives: **settled** = its verdict
rests on a fact (a path, a tag, a tracked file) and has held; **needs watching** = its verdict rests on
a threshold or a wording chosen by hand, so it can be wrong in both directions.

⏱ **Durations are the MEDIAN of three consecutive runs, wall clock, measured 2026-08-05 (Darwin arm64).** An earlier column held single cold runs on a busy machine and was wrong by 1,7× to 4,1×. They do not add up: `check.sh` starts them together, so the lot costs its slowest — **the gate (`--house`) runs in 3,05 s, a commit in 1,09 s, the full lot in 5,31 s**.
not add up: `check.sh` starts them together, so the lot costs its slowest, not their sum — the whole
gate runs in about 3,7 s. Anything under 0,4 s does not show at all.

| Control | Looks for | Where | When | Travels | Maturity | Time | Blocks? |
|---|---|---|---|---|---|---|---|
| `gitleaks` *(hook)* | a secret in the staged files | local | every commit | ✅ | settled | 0,3 s | ✅ **the only local blocker** |
| `pre-push` *(hook)* | a push straight to `main`/`develop` | local | every push | ✅ | settled | instant | ✅ |
| `gitleaks` *(CI)* | a secret anywhere in the **whole history** | GitHub | every PR | ✅ | settled | ~2 s | ✅ |
| `semgrep` | flaws in the application code | GitHub | every PR | ✅ | settled | ~15 s | ✅ |
| `osv-scanner` | dependencies with a known vulnerability | GitHub | every PR | ✅ | settled | ~3 s | ✅ |
| `actionlint` | broken syntax or shell in the workflows | GitHub | every PR | ✅ | settled | ~1 s | ✅ |
| `zizmor` | a `${{ }}` injected into a `run:`, an unpinned action | GitHub | every PR | ✅ | settled | ~4 s | ✅ |
| `shellcheck` | bugs in the shell scripts | both | a `.sh` moved | ✅ | settled | ~1 s | ✅ |
| `renovate-config-validator` | a Renovate config so broken updates freeze | local | that file moved | ✅ | settled | ~4 s | ✅ |
| `trivy` *(`build-check`)* | a CRITICAL/HIGH CVE in the image — capability `artefact` | GitHub | every PR | ✅ | settled | ~30 s | ✅ |
| `trivy` *(weekly)* | the **published** image going vulnerable with nothing saying so | GitHub | weekly | ✅ | settled | ~30 s | ❌ it alerts |
| `CodeQL` | flaws spanning several files — **public repositories only** | GitHub | PR + weekly | ✅ | settled | ~2 min | ✅ |
| `dependency-review` | a vulnerable or badly-licensed dependency getting **in** — public only | GitHub | every PR | ✅ | settled | ~5 s | ✅ |
| `checks/verify-tone.sh` | the second person (`you`/`your`, `tu`/`vous`) in published content | both | every commit | ✅ | settled | 0,08 s | ✅ |
| `checks/verify-narrative.sh` | a dated story told in a code comment — it belongs in the archive | both | every commit | ✅ | settled | 0,08 s | ✅ |
| `checks/verify-workspace.sh` | two tracking systems competing, or a secret tracked by git | both | every commit | ✅ | **needs watching** — the list of rival tools cannot be complete, and it names what it looked for | 0,12 s | ✅ |
| `checks/verify-links.sh` | a relative link or an anchor leading nowhere | both | every commit | ✅ | settled | 0,11 s | ✅ |
| `checks/verify-checks-wiring.sh` | a control declared nowhere, or **the gate missing from a workflow** | both | every commit | ✅ | settled | 0,06 s | ✅ |
| `checks/verify-memories.sh` | a memory absent from its index, a `[[link]]` leading nowhere | local | every commit | ✅ | settled | 0,06 s | ✅ *(nothing to read under CI, and it says so)* |
| `checks/verify-do-not-break.sh` | the four wirings whose breakage makes no sound | both | every commit | ✅ | settled | 0,08 s | ✅ |
| `checks/verify-checksums.sh` | an `.html` that stopped saying what its `.md` says | both | every commit | ✅ | **needs watching** — a matching checksum proves the file was touched, never that it says the same thing | 0,10 s | ✅ |
| `checks/verify-secret-blindspots.sh` | a file NAMED like a secret, a password inside a remote URL | both | every commit | ✅ | settled | 0,12 s | ✅ |
| `checks/verify-changelog.sh` | a user-visible change with no `CHANGELOG` line | both | every commit | ✅ | settled *(perimeter detected, and measured: 3 of the last 40 PRs)* | 0,10 s | ✅ |
| `checks/verify-growth.sh` | a curated document that only ever grows | both | a `.md` moved | ✅ | **needs watching** — the 25 % threshold is a judgement call | 0,91 s | ✅ *(made blocking 2026-08-05)* |
| `checks/verify-comment-drift.sh` | a comment growing faster than the code it explains | both | a `.sh` moved | ✅ | **needs watching** — it compares PERCENTAGES, so it over-reports on a small file: measured 2026-08-05, +134 % of comment against +94 % of code was **34 lines against 36** | 0,85 s | ✅ *(made blocking 2026-08-05)* |
| `checks/verify-version.sh` | the tag, the `CHANGELOG` and every script disagreeing on the version | both | every commit | ✅ | settled *(needs `fetch-tags`, or it passes by finding nothing)* | 0,55 s | ✅ |
| `checks/verify-echo.sh` | two paragraphs stating the same thing in different words | both | a `.md` moved | ✅ | **needs watching** — measured limit: a restatement that changes vocabulary scores 0,32 against a 0,40 threshold | 0,25 s | ✅ *(made blocking 2026-08-05)* |
| `checks/verify-travel.sh` | a path written here that leads nowhere once the file has shipped | both | `templates/`, `checks/` moved | ✅ | settled | 1,77 s | ✅ |
| `checks/verify-delegation.sh` | a subagent launched without its three instructions | local | before the launch | ✅ | **needs watching** — a hook, and a hook nothing declares simply never fires | instant | n/a — refuses the launch |
| `checks/verify-forbidden-command.sh` | a command forbidden here, before it runs | local | before the command | ✅ | **needs watching** — same reason | instant | n/a — refuses the command |
| `checks/verify-turn-claims.sh` | what the assistant ASSERTS as a turn ends, against what the turn ran | local | end of turn | ✅ | **needs watching** — its two patterns were tuned on 4463 real turns; they fire on under 1 %, and a rewording moves that | instant | n/a — reports only |

> **Travels: yes, all of them, and that is the rule** — `init-project.sh` copies `checks/` whole, and
> a control DETECTS whether its subject exists where it lands: present it bites, absent it says so.
> The three hooks travel too; a project that wants them has to declare them in its own settings.
> The external tools travel through the workflow templates, at the versions those files pin.
>
> ⚠️ **`local`, `GitHub` or `both`** describes where the control RUNS, never what it may look at.
> `verify-memories.sh` runs at the gate like the others — it reports there that it found no memories
> to read, which is a verdict where silence was not one.

### What is merely SET on the server

These are not run, they are **in force**. All of them require a **public** repository *(rulesets, secret
scanning and CodeQL are unavailable on private/Free — the visibility gate)*.

| Control | What it prevents | Set by |
|---|---|---|
| `main` ruleset | a merge with no PR, a red merge, a force-push | `configure-repo.sh` |
| `develop` ruleset *(capability `staging`)* | same, minus CodeQL, which never analyses that branch | `configure-repo.sh` |
| `tags` ruleset + immutable releases | a released tag being moved, its assets replaced — **without both, pinning a version in production guarantees nothing** | `configure-repo.sh` |
| secret scanning + push protection | a known secret reaching the server at all | `configure-repo.sh` |
| private vulnerability reporting | a researcher having no way to report privately, so publishing instead | `configure-repo.sh` |
| Dependabot alerts | a dependency going vulnerable with nothing saying so | `configure-repo.sh` |
| Renovate | dependencies and pinned tools falling behind | `renovate.json` |

### The GATE — one line, and it is the same one everywhere

`./check.sh --house` runs the house checks **and nothing else**: `gitleaks`, `semgrep`, `osv-scanner`, `actionlint` and `zizmor` are the CI's own steps, at versions it pins and checksums itself, and replaying them inside the same job would download and rerun the whole lot for the same verdict.

That single line is what every gating workflow calls — this repository's `ci.yml` and the three shipped `templates/workflows/ci-*.yml`. **It used to be a step per check, written by hand in each file**, which is a list, in four places, that has to be edited in every direction the day a check is added. `verify-checks-wiring.sh` fails the build if the line goes missing from any of them.

⚠️ **Two conditions belong to the checkout, not to the script**, and each one turns a guard blind without failing: `fetch-depth: 0` *(`verify-changelog.sh` compares against a merge base)* and `fetch-tags: true` *(`verify-version.sh` reads the tag, and finds nothing without them)*.

### The THREE RHYTHMS — what triggers each, and what each costs

The split is not how long a check takes, it is **what has to change for it to say something other than yesterday**. There are only two answers, and they give the rhythms `check.sh` implements.

| Rhythm | What makes the verdict new | What runs there |
|---|---|---|
| **every commit** — `./check.sh --commit` | any file of the tree | every check in the table above **except the four below and the three hooks**, plus `gitleaks` over what is not pushed yet *(a cost that stays flat as the repo grows)* |
| **every commit, if its target moved** | a `.sh`, a workflow, a `renovate.json`, a file that travels, **a `.md`** | `shellcheck` · `actionlint` + `zizmor` · the Renovate validator · `verify-travel.sh` *(it generates a whole project)* · **`verify-echo.sh`** and **`verify-growth.sh`** on a `.md`, **`verify-comment-drift.sh`** on a `.sh` — each on ITS OWN target. Pairing two of them under one condition once blinded the script half on a commit that touched only scripts |
| **every 6 h** — `./check.sh`, and the CI | an external base, or a tool version | `osv-scanner` *(the OSV database is queried online)* · `semgrep` *(its packs are downloaded)* · `gitleaks` over the full history *(its rules are baked into a pinned binary)* |

**What a commit costs, by what it touches** *(wall clock, measured 2026-08-04 — Darwin arm64)*. 🔴 **A duration only means something alongside WHAT MOVED**: the same `--commit` spans 0,8 s to 2,6 s, and a figure quoted without its case was once read as wrong by a factor of 2,7 when it was simply measuring another one.

| The commit touches… | What that wakes on top | Wall clock |
|---|---|---|
| nothing *(clean tree)* | — | **0,8 s** |
| a workflow | `actionlint` · `zizmor` | **1,5 s** |
| a `.md` | `verify-echo` · `verify-growth` | **1,9 s** |
| a `.sh` | `verify-comment-drift` · `shellcheck` *(whole tree)* | **2,2 s** |
| `templates/` | `verify-travel` *(it generates **four** projects)* + both `.md` ones | **3,7 s** |
| `.md` + `.sh` + a workflow | everything above | **2,6 s** |
| `./check.sh` in full | `osv-scanner` + `semgrep`, both over the network | **5,0 – 5,6 s** |

**Parallelism absorbs, and the numbers say so**: the house checks add up to **5,1 s** of their own time, and the full lot takes **5,0 – 5,6 s** while adding osv, semgrep and gitleaks on top. **The slowest by far is `verify-travel` (1,66 s), which generates four projects in series**, then `verify-echo` (1,36 s), `verify-comment-drift` (0,83 s) and `verify-growth` (0,48 s); every other one sits under 0,11 s. Adding a check below ~0,4 s does not show.

> ⚠️ **`verify-travel` costs what it costs because it covers five toolchain/capability combinations instead of one** *(0,46 s → 1,66 s, measured 2026-08-04)*. It only starts when `templates/`, `checks/`, `check.sh` or `init-project.sh` moved, so it is paid on four file paths and nowhere else. **The generations run in series on purpose**: parallelising them would save about a second, at the price of no longer being able to say WHICH variant failed to generate — and a check that fails without saying why is a defect this repo has already fixed once.

> **A hook DECLARES ITSELF**, in its own header — `# hook: <event>`. `check.sh` detects that line rather than naming the hooks, which was the last hand-written list left in it, and the one that travelled into every project with nothing to guard it. A fifth hook dropped into `checks/` would have joined the parallel lot and hung on STDIN, with no output at all.
>
> **The three hooks are outside all of this.** `verify-delegation.sh`, `verify-turn-claims.sh` and `verify-forbidden-command.sh` are fired by the assistant's own events, not by `check.sh` — which must never start them: each reads its payload from STDIN, and inside the parallel lot they would compete for it with every sibling. A check skipped by its rhythm says so **as a skip**: a missing capture otherwise reads as "it never ran", and a skip that looks like a breakage is how a real breakage stops being noticed.

🔴 **A check that reads the tree reads ALL of it, in both modes.** Narrowing one to the diff is blind by construction: deleting a file breaks a link in another one, and no diff mentions that. What the changed files decide is whether a check **runs**, never what it looks at.

🔴 **A check publishes WHAT IT READ, never a bare tick.** An absent root, a glob matching nothing and a `|| true` swallowing an error all produce zero targets, and zero targets reads exactly like a clean tree. Three checks were caught claiming *"in both repos"* with the neighbouring `workspace/` renamed away; each now names what it read and what it did not.

---

## GitHub repo configuration

The whole config/maintenance spectrum for a public repo is **one-shot**: set at creation via `configure-repo.sh`, then forgotten.

In short: **CodeQL in native *default setup*** · Dependabot · secret scanning + push protection · **private vulnerability reporting** · `main` ruleset (+ `develop` if it exists) · **tag ruleset** · **immutable releases** · third-party actions pinned to SHA · minimal `permissions:`. The assistant's PAT manages alerts autonomously, **never touching `Administration: write`** *(the two-tier PAT matrix: `secrets-and-auth.md`)*.

> 🔎 **`immutable releases` is scriptable, not UI-only.** The `PUT /repos/{owner}/{repo}/immutable-releases` endpoint exists and falls under `Administration: write`, **already** part of the admin PAT recipe: **nothing to add, everything to automate**.

### 🔴 CodeQL: **default setup**, and above all NO committed `codeql.yml`

**There is no more `codeql.yml` in the template.** `configure-repo.sh` enables GitHub's **default setup** via the API *(`PATCH /repos/{o}/{r}/code-scanning/default-setup`, `Administration: write` — already in the admin PAT recipe)*.

**Why native wins here — and it's not a matter of taste:**

| | our old `codeql.yml` | **default setup** |
|---|---|---|
| Languages analyzed | **ONE, hard-coded** | **all**, **auto-detected** |
| A language shows up in the repo | **ignored forever** *(no one thinks to edit the YAML)* | **analyzed automatically** — [GitHub updates the config](https://github.blog/changelog/2023-06-26-code-scanning-default-setup-automatically-updates-when-the-languages-in-the-repository-change/) |
| Scheduled scans | a `cron` we maintain | **included** |
| Maintenance | **ours** | **GitHub's** |

> 🔴 **This wasn't a preference, it was a HOLE**: a `codeql.yml` hard-coded to one language leaves **the rest of the repo unanalyzed** — including its own workflows. The custom code was **degraded** native, and it degraded a **security control**.

**What default setup can't do** *(the exit door, if a project ever needs it)*: custom query packs · `paths-ignore` · custom build steps · uploads from an external CI.
→ **Only then**, go back to a committed `codeql.yml` — **and declare ALL the repo's languages by hand**, for good.

**Consequences not to miss:**
- **PRIVATE repo (Free)**: default setup is **unavailable** *(GHAS required)* — exactly like the workflow was. **Nothing changes**: `Semgrep` + `osv-scanner` remain the mitigation *(see "The hole in the private phase", below)*.
- **CodeQL no longer "wakes up" on its own at the flip**: it's **rerunning `configure-repo.sh`** that enables it — and that rerun is **already mandatory** in the visibility-flip procedure *(below)*. No new action.
- A **legacy** repo still carrying a `codeql.yml`: enabling it moves it to **`disabled_manually`** — GitHub refuses both modes at once. The script **says so** instead of doing it silently. **Then delete the file: an orphaned workflow is a control nobody reads anymore.**
- The check run **keeps the name `CodeQL`**: the `code_scanning` ruleset rule *(`tool: CodeQL`)* is **unchanged**, and keeps blocking PRs.

### Recommended controls (industry best practices)

| Control | What it prevents | Where |
|---|---|---|
| **Ruleset on `v*` tags** (`deletion`, `update`) | A release tag being **moved or deleted**. **Without it, the version pin above guarantees NOTHING**: prod pins `X.Y.Z` believing it froze an artefact, while the tag can point elsewhere tomorrow. | `configure-repo.sh` |
| **Immutable releases** *(GA 2025-10-28)* | A published release's **assets** being **replaced**. It's the counterpart of the `tags` ruleset: that one freezes the **tag**, this one freezes the **content**. Without both, the version pin can be bypassed **without touching the tag** — republishing a different binary under the same one. **NOT RETROACTIVE: "immutability will only apply to future releases" → set BEFORE v1.** | `configure-repo.sh` *(at the public flip)* |
| **Private vulnerability reporting** | An external researcher having **no way to report privately** — and so publishing the flaw as a public issue instead. **Without it, the `SECURITY.md` link is DEAD.** | `configure-repo.sh` |
| **`dependency-review-action`** (PR) | A vulnerable or badly-licensed dependency **getting in**. Dependabot only alerts **AFTER** merge: the two are complementary, not redundant. | `ci-node.yml` |
| **`actionlint` + `zizmor`** (PR) | **The workflows themselves** being the hole: a `${{ }}` interpolated into a `run:` is a **shell injection**. | `ci-*.yml` |
| **`persist-credentials: false`** | The `GITHUB_TOKEN` **lingering in `.git/config`** and leaking via an artefact (the `artipacked` audit). | every `checkout` |
| **`default_workflow_permissions: read`** | A **future** workflow, written without a `permissions:` block, inheriting a **write** `GITHUB_TOKEN`. Our workflows all declare it — this is a safety net, not an immediate gain. | `configure-repo.sh` |
| **Renovate `groupName`** | **Noise**: minor + patch grouped into **one** PR. **Majors stay isolated** — a major can break things, it deserves to be looked at alone. | `renovate.json` |
| **Trivy** on the image (PR) — *capability **`artefact`*** | An image carrying a **CRITICAL/HIGH** CVE reaching `main`. Scanning **at deployment is too late**: the image is already tagged and prod pins it. The **`build-check`** job is a **REQUIRED** check — otherwise the scan is **decorative**. | `docker-publish.yml` |
| **Weekly Trivy on the PUBLISHED image** — *capability **`artefact`*** | An image **already in prod** becoming vulnerable **with nothing saying so**. The PR gate no longer looks at anything after merge, and Renovate only catches up if the base image **moves**: a line of images that **stops being rebuilt** produces no bump, no PR, no scan — the CVE keeps being served. **This is a watch scan, not a gate**: it isn't required anywhere, it **alerts**. | `docker-publish.yml` |

> **Pinning policy — `.github/zizmor.yml`**: full SHA required for **any third-party action**; **a major-version tag tolerated for `actions/*` and `github/*`** (compromising them means compromising GitHub itself). This isn't fussiness: in **March 2026, 75 of the 76 tags of `aquasecurity/trivy-action` were force-pushed**. A tag is mutable; a SHA is not.

### Setup — scriptable vs UI (for `configure-repo.sh`)

> 🔴 **VISIBILITY decides more than the plan.** Five controls are **impossible** on a **private** repo — and **not purchasable**: the org must first move to Team, *then* buy the product. On a **public** repo, they are **free**, even on Free.
>
> | At the public FLIP only | From CREATION, private included |
> |---|---|
> | secret scanning · push protection · CodeQL · **rulesets** · PVR *(VISIBILITY gate, not plan)* | repo core · merge · `GITHUB_TOKEN=read` · Dependabot alerts + security updates · **immutable releases** · fork-PR · retention |
>
> ➡️ **Practical consequence**: making a repo public is a **security** decision, not just an openness one. And `configure-repo.sh` **reads `visibility`** to apply this split — it is therefore **built to be re-run at the flip**.
>
> ⚠️ **Never read a missing field as "disabled"**: without `Administration`, `security_and_analysis` doesn't error — the key is simply **omitted**. "Empty" ≠ "off".

| Setting | How |
|---|---|
| **Immutable releases** | `gh api -X PUT repos/{o}/{r}/immutable-releases` (`Administration: write` — **already** in the admin PAT's recipe). 🔴 **NOT RETROACTIVE** → set **from private on** *(the setting is available there)*, never deferred to the flip: whatever isn't covered when a release is published **never** will be. |
| **Private vulnerability reporting** | `gh api -X PUT repos/{o}/{r}/private-vulnerability-reporting` — **public-only** *(moot on private: no external researcher can access it)*. |
| **`sha_pinning_required`** *("Require actions to be pinned to a full-length commit SHA")* | `PUT /repos/{o}/{r}/actions/permissions` — scriptable, available on private Free. ⏸️ **Deliberately NOT set**: the native toggle is **stricter than the repo's convention**, which tolerates the major tag for `actions/*` and `github/*`. Enabling it would force everything to full SHA, first-party included. *(zizmor already covers third parties.)* |
| **Dependabot malware alerts** | ⚠️ **UI, no API** *(no `security_and_analysis` field, no endpoint)* — **npm-only**, available from private Free. Detects the **malicious** package, an angle Renovate doesn't cover *(it remedies CVEs via a version bump; a malicious package often has no safe version)*. → the maintainer's action, RUNBOOK §1 step 9. |
| CodeQL | **`PATCH /repos/{o}/{r}/code-scanning/default-setup`** (`Administration: write`) — **scriptable, and IN `configure-repo.sh`** |
| Dependabot alerts | `gh api -X PUT repos/{o}/{r}/vulnerability-alerts` |
| Secret scanning / push protection | `gh api -X PATCH repos/{o}/{r} -f security_and_analysis[...][status]=enabled` |
| **Dependabot security updates** *(the safety net — **2 stages only**: at 3 stages, `DELETE` on the same endpoint, cf. `security-and-updates.md`)* | `gh api -X PUT repos/{o}/{r}/automated-security-fixes` — 🔴 **DEDICATED endpoint, NOT a sub-key of `security_and_analysis`**: `dependabot_security_updates` is in the GET's **response** schema, **not** in the PATCH's body params. Passing it to the PATCH **raises no error** — it is ignored, **silently**. |
| Rulesets | `gh api -X POST repos/{o}/{r}/rulesets --input ruleset.json` (`gh ruleset` = read-only) |
| Topics / homepage / merge-methods / delete-branch | `gh repo edit --add-topic … --homepage … --enable-squash-merge --delete-branch-on-merge` |
| Renovate · gitleaks · npm audit · CI updates | **committed files** (`.github/renovate.json`, `.github/workflows/*.yml`), no API |
| 2FA | **UI-only** (no endpoint) |
| **Reading the packages / ghcr API** | ❌ **IMPOSSIBLE on fine-grained** — GitHub Packages is **not supported** by fine-grained PATs (classic `read:packages` only). There is no point adding the permission: **it doesn't exist**. → **Moot**: the right test is an **ANONYMOUS pull** of the registry (`ghcr.io/token` + `/v2/<img>/manifests/<tag>` → **200 = pullable**), which verifies *exactly* what the prod host does, **with no token at all**. Set by `configure-repo.sh`. |
| **ghcr package visibility** | ⚠️ **UI, no API** *(fine-grained PATs do NOT cover ghcr — only `classic` PATs do)*. 🔴 **The default DEPENDS ON THE OWNER, and confusing it is costly:** on a **PERSONAL** account, a package published from a **public** repo is pullable **anonymously, WITH NO ACTION AT ALL** *(HTTP 200 — verified on test003)*. On an **ORGANIZATION**, it is **PRIVATE by default** → an anonymous `docker pull` = **403**, and **no one can self-host** *(verified on test004)*. → **`configure-repo.sh` TESTS the anonymous pull** and only asks for the action **IF the test fails**. *(Org-wide: Settings → Packages → Package creation → default visibility.)* **When the action IS needed** *(org)*: Package settings → Danger Zone → *Change visibility* → **Public**. Without it, neither the prod host nor a user can pull the image — and **the production version pin is worth nothing anymore**: it points to an image no one can retrieve. |
| **Reported content** (moderation) | **UI-only — NO API** (verified: no moderation endpoint exists). Exact path, scope (org only) and item count: **RUNBOOK §4, step 5**. ⚠️ The box **is not checked** on "All users". |

> **Dry-run first**: on a personal account, some `security_and_analysis` sub-keys (`advanced_security`, `code_security`) are probably no-ops outside GHAS/org. This should be tested on the target repo before hard-coding it into `configure-repo.sh`.

### OpenSSF Scorecard — keep / drop (solo, public, small)

- **Keep** (~zero cost): Token-Permissions · Branch-Protection · Pinned-Dependencies · Dangerous-Workflow (no `pull_request_target` + PR checkout) · Security-Policy (`SECURITY.md`) · SAST (CodeQL) · Dependency-Update-Tool (Renovate).
- **Drop** (overkill solo): Signed-Releases · Fuzzing · CII-Best-Practices badge · signed commits (friction with no gain against oneself).
- **2FA**: yes, non-negotiable — but an **account** setting, enabled in the UI.

> ⚠️ **Adopting some of Scorecard's practices is not running Scorecard.** The list above picks the *checks whose practice is worth holding*; the **tool itself** is rejected below, and the two are not in conflict.

**Rejected, after review**: SLSA attestations (no one else consumes the images → signing into a void) · OpenSSF Scorecard **as a tool** (measures *process* compliance, a gameable score) · CODEOWNERS and merge queue (multi-contributor territory).

---

## The control matrix — what, where, when, by whom

> Principle: **every defect is caught as early as possible**, and each stage catches what the previous one let through.

| Stage | Controls | When | By whom |
|---|---|---|---|
| **Pre-commit** *(local)* | **gitleaks** (staged files) — **and nothing else**: no lint. *No linter is universal across the three toolchains (static has no toolchain, node depends on the project, generic is a stub to fill in): forcing an `eslint` that half the projects don't have would fail the hook on the very first commit. Lint belongs to the project, not the template.* | on every commit | dev machine |
| **Push** *(server)* | **secret scanning push protection** | on every push | GitHub |
| **PR** *(CI)* | **gitleaks** (**full** history) · **actionlint** + **zizmor** (the workflows) · **Semgrep** + **osv-scanner** *(the only ones that run in PRIVATE — see below)* · **CodeQL** *(public only)* · tests + typecheck + `npm audit` + **dependency-review** *(public only)* + **Trivy on the image** (*`artefact` capability* — **not** "node": a `static` site that publishes an image has it too) · syntax-check (`static` toolchain) | on every PR | GitHub Actions |
| **Server** | `main` ruleset (+ `develop` if it exists): PR required, **required checks (`checks` + CodeQL + `build-check` if a Docker image)**, no force-push/deletion · **`v*` tags ruleset** (no deletion or moving) **+ immutable releases** (no asset replacement) — *both, otherwise the version pin can be bypassed* · secret scanning · **private vulnerability reporting** | continuously | GitHub |
| **Scheduled** | CodeQL · **Dependabot alerts** *(CVE detection)* · **Renovate** *(version updates + auto-merged security remediation)* · **Trivy on the published image** *(`artefact` capability)* | weekly | GitHub · Renovate · GitHub Actions |
| **Rotation** | Write PAT — **J-14 alert** in `.envrc` (`secrets-and-auth.md`) | every 90 days | Claude alerts · the maintainer regenerates |

> **Three barriers actually block, and they're redundant on purpose**: the **hook** catches early but is *local*, bypassable (`--no-verify`), and **absent from a fresh clone**; **push protection** only catches *known* GitHub patterns; **CI** scans the whole history and **guarantees** — it's the only one nobody can skip, because the ruleset requires it before merge.

### In private, NOTHING is enforced — discipline is the only net, so it's TOOLED

On a private/Free repo, **there is no ruleset at all**. Every control **runs**, **none is required**: GitHub would accept a `git push` **directly to `main`**, and a **red** PR can be merged. Coverage is good; it's **forced execution** that's missing.

> ⚠️ **Discipline that's only written down doesn't exist.** So it's carried by tooling everywhere that's possible, and reduced to a single human rule where it isn't.

| What must be upheld | How it's upheld | Bypassable? |
|---|---|---|
| No secret committed | **`pre-commit`** hook (`gitleaks`) | `--no-verify` → **CI replays it on the full history** |
| **No direct push to `main`/`develop`** | **`pre-push`** hook — *the substitute for the missing ruleset* | `--no-verify` (**a decision, not an accident**) |
| **Never merge a red PR** | ❗ **human rule** — verify that **every expected workflow** is `completed / success` *(command below — above all **not** `gh pr checks`)* | nothing stops it server-side |

> 🔴 **`gh pr checks <n>` is UNUSABLE with this standard's PAT — the rule was written everywhere, and unusable everywhere.**
> It reads `statusCheckRollup`, which requires the **`Checks`** permission. This permission is **documented** by GitHub but **absent from the UI** for fine-grained PATs: it **cannot be granted** *(github/community#129512, cli/cli#12597)*. Result: `Resource not accessible by personal access token`. *(`gh pr view <n>` alone fails for the same reason.)*
> **Nothing to add to the PAT** — the command below only needs `Actions: read`, already in the matrix (`secrets-and-auth.md`).
>
> ```bash
> sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)   # --json targets → no rollup requested
> gh run list --commit "$sha" --json workflowName,status,conclusion
> ```
>
> **Green ⇔ every expected workflow is `completed / success`** — the exact set, and why a missing workflow is not a green: [`AGENTS.md`](../AGENTS.md#discipline-pr-only).

The `pre-push` hook **lets branch creation through** (otherwise a fresh repo's first push would be impossible) and **stays active in public** — the server then refuses the same push, but the local message is far clearer. *Defense in depth.*

**The one truly human point is merging a red PR**: no hook can intercept it, the merge happens server-side. → written into **`AGENTS.md`** (so read by agents) and into `CONTRIBUTING.md`.
**All of this fades away at the public flip**: rulesets then *require* the checks, and the server enforces what discipline alone used to hold.

### The hole in the private phase — and why Semgrep + osv-scanner exist

**A repo spends its whole youth private.** Yet on private/Free, **CodeQL and `dependency-review` are unavailable** (they require GHAS). Without a mitigation, **the code is never statically analyzed** until flip day — and CodeQL then dumps **the entire backlog at once**.

> 🚫 **Verified dead end: CodeQL is FORBIDDEN on private code — by LICENSE, not by a technical limit.** The CodeQL CLI license excludes *"any codebase that is not an Open Source Codebase (e.g., code in a private repo)"* except with a **paid GHAS license** (~$30/committer/month, Team plan). **No legal workaround**, even locally. → **GHAS rejected**: paying for a **transitional state**, when everything becomes **free** as soon as the repo goes public.

| Tool | In private | Role | Limitation to know |
|---|---|---|---|
| **Semgrep OSS** | ✅ free, **no account or token** | Static analysis — **partial but real** overlap with CodeQL | **File by file**: no cross-file analysis. It **PRECEDES** CodeQL, it does **not** replace it. |
| **osv-scanner** | ✅ free (Apache-2.0) | **The equivalent of `dependency-review`, which does work in private** | OSV database: no **license** check → `dependency-review` stays useful in public. |

**Kept PERMANENTLY**, not just in private: Semgrep catches what CodeQL misses, and **the private phase is when the most code gets written** — so it's when *more* signal is wanted, not less.

⚠️ **`--exclude=.github` on Semgrep, and it's deliberate**: its rules on workflows **contradict** our pinning policy (SHA for third parties, major tag tolerated for `actions/*` — cf. `.github/zizmor.yml`). Without this exclusion, **every fresh scaffold fails on its very first PR**. Workflows already have **their own dedicated linters** (`actionlint` + `zizmor`). **One scope per tool, no overlap.**

**What this doesn't solve**: CodeQL's first pass at the flip remains **an assumed triage step** — but on code **already cleared**, it's a *residue*, not an avalanche.

### The matrix is NOT uniform — it depends on visibility

| Stage | **Public** repo (Free) | **Private** repo (Free) |
|---|---|---|
| Pre-commit | ✅ | ✅ |
| PR (CI) | ✅ | ✅ |
| Server (ruleset, secret scanning) | ✅ | ❌ **unavailable** |
| Scheduled — CodeQL | ✅ | ❌ **unavailable** |
| Scheduled — Renovate + Dependabot alerts | ✅ | ✅ *(free in private)* |

**Consequence, not to miss**: on a **private** repo, the *server* and *CodeQL* stages are **empty**. **Pre-commit becomes the only anti-secret net** — `gitleaks` there isn't a nicety, it's the only barrier. That's what makes pre-commit the **foundation**, not a refinement.

A private repo gains the three missing stages **all at once** by going public → that's the moment to rerun `configure-repo.sh` *(RUNBOOK §1, step 7)*, **after** a `gitleaks detect` on the **full history**: at the visibility flip, a secret buried in an old commit becomes public.

### Implementation

- **Hook**: `repo/.githooks/pre-commit` — **versioned** (hence shared), enabled via `git config core.hooksPath .githooks` (set by `init-project.sh`; **a fresh clone must set it again**).
  It runs `gitleaks git --staged --redact`: **exit 1 → commit blocked**, silent when everything is fine. **Hard failure if gitleaks is missing** — a missing scanner must never look like a clean scan.
- **CI**: **pinned `gitleaks` binary + verified checksum** (⚠️ **NOT `gitleaks-action`**: it requires a **license** on an **ORGANIZATION** repo → CI would be **red by default**), with `fetch-depth: 0` → scans the **full history**, on **both** toolchains.

### Why pre-commit alone isn't enough

A local hook is **bypassable** (`git commit --no-verify`) and only exists on the machine that installed it. Hence the duplication with **gitleaks in CI**: the hook catches early, CI **guarantees**. Both, not either.

### ⚠ Auditing a history: scan `main`, NOT the current branch

`gitleaks git` scans the history reachable from **HEAD**. Run from a working branch, it says **nothing** about the state of `main` — the two histories diverge as soon as they have their own clean commits.

**Correct procedure** — from a detached worktree on the target, so as not to disturb the working tree:
```bash
git fetch origin main
git worktree add --detach /tmp/scan origin/main
( cd /tmp/scan && gitleaks git --no-banner --redact )
git worktree remove --force /tmp/scan
```
**Before a private → public switch**, it's **every ref** that needs covering, not just `main`: a secret in an old pushed branch becomes public too.

### False positives: pin by fingerprint, never disable the rule

A **public** identifier shaped like a secret (contract address `0x…`/`C…`/`G…`, XDR transaction, password hash) triggers the `generic-api-key` rule. These cases are neutralized in a **versioned `.gitleaksignore`**, by **fingerprint** (`commit:file:rule:line`) and **commented** — never by disabling the rule: a **real** secret in the same file must still get caught.

---

## The private → public switch — **a normal step in the flow**, not a special case

**This is the nominal path**: every repo is born private and later flips public. A private repo on Free has **no ruleset, no CodeQL, no secret scanning** — it gains **all of them at once** at the flip.

| While private — *everything runs, nothing is required* | On going public — *the server enforces what discipline used to hold* |
|---|---|
| ✅ gitleaks (hook + CI, full history) | ✅ `main`, `develop`, `tags` rulesets |
| ✅ `pre-push` hook: no direct write to `main` | ✅ **Required** checks before merge |
| ✅ semgrep · osv-scanner | ✅ Secret scanning + push protection |
| ✅ actionlint · zizmor · trivy | ✅ CodeQL — *scans the whole history at once* |
| ✅ tests · typecheck · Renovate + Dependabot alerts | ✅ dependency-review · immutable releases |
| ❌ **No ruleset** — a red PR can be merged | ✅ Private vulnerability reporting |

> ⚠️ **The flip is the most dangerous moment in a repo's lifecycle**: **the entire history goes public at once**, including a secret buried in a six-month-old commit — and it will have been pushed during the phase where **no server-side secret scanning existed at all**. Hence the gitleaks pass over every ref, below, non-negotiable.

**What the switch requires, and why** *(exact sequence — who does what, in what order: RUNBOOK §4)*:

- **`gitleaks` on EVERY ref**, not just `main`, from a **detached worktree** *(procedure above, "Auditing a history")* — a secret in an old pushed branch becomes public too.
- **Rerun `configure-repo.sh`** (**ephemeral** admin PAT): it sets the `main` ruleset, secret scanning + push protection, Dependabot, **immutable releases**, description, **topics**, **enables CodeQL** *(default setup)*, and picks the **merge method based on the `staging` capability** (squash only; + merge commit if `develop` exists — squash-only is incompatible with a staging branch). The script is **idempotent**: safe to rerun.
- **Nothing to do for the workflows.** `pages.yml` carries `if: github.event.repository.visibility != 'private'`: it is **`skipped`** in private and **wakes up on its own** at the flip. ⚠️ **CodeQL, though, is NO LONGER a workflow** *(no more `codeql.yml`)*: it's rerunning `configure-repo.sh` that enables it, in *default setup*, and **waits for its first analysis** before setting the `code_scanning` rule — otherwise `main` would be left unguarded.
- **ORG repo — SYSTEMATIC, never an exception**: the "Reported content" moderation setting is **UI-only** (no REST/GraphQL API) and is only applied by default to repos **created public** — so **never to ours**, born private. Without it, community health caps out. **Exact path + value: RUNBOOK §4, step 5.**
- **Then verify, read-only**: community health **100%** · CodeQL **green** · ruleset **active** · secret scanning **on**.

> **Why the workflows manage themselves instead of being added at the flip**: a manual procedure is a recurring, *forgettable* cost. A job that fails on every run on a private repo makes CI permanently red — and **CI that's always red stops being read**. The condition is written `!= 'private'` (never `== 'public'`): if the field were ever missing from the payload, the job **runs** (noise) instead of **silently disabling a security control**. **CodeQL was the exception to this principle, and it was the wrong tradeoff** — its `codeql.yml` did manage itself, but at the cost of one frozen language nobody kept updated. The action already existed: rerunning `configure-repo.sh` is mandatory at the flip.

---

## Acquiring a CAPABILITY on an already-live repo

The repo keeps everything else: the category doesn't change, a capability is **ACQUIRED**. A Pages site that starts publishing an image **stays** a Pages site.

`init-project.sh` sets capabilities **at creation**. Here the repo already has history, rulesets, and required checks: the generator isn't rerun, capabilities are **added** — in the right order.

> ⚠️ **THE ORDER IS THE TRAP, and it's counter-intuitive.** `configure-repo.sh` makes `build-check` **required** as soon as it sees `docker-publish.yml` on `main`. Run **before** the workflow is there, it demands a check **that will never report**: every PR stays blocked forever on *"Expected — waiting for status"* — **including the one that brings the workflow**. The repo **locks itself out**.
> **→ The workflow must reach `main` BEFORE the script requires it.** This rule applies to any capability that adds a **required check**.

### Acquiring `--artefact` — "third parties should be able to self-host my project"

*The Pages-site-plus-Docker case: a Pages page later packaged as an image so third parties can deploy it and track updates. **Pages stays**, and there is **no `develop` to create** — no host exists that needs validation.*

*(Exact sequence — who does what, in what order: RUNBOOK §5.)*

- `Dockerfile` + `docker-publish.yml` arrive **via PR**, before `build-check` becomes required — that's what avoids the ordering pitfall (above: "the order is the trap").
- **Static page → `FROM nginx:alpine`** *(a web server, not a toolchain — `docker-hardening.md`)*, **followed by `RUN apk upgrade --no-cache`.** 🔴 **This line is NOT cosmetic**: `nginx:alpine` lags behind Alpine packages and can carry HIGH CVEs already fixed upstream. Trivy runs with `--ignore-unfixed`: it surfaces **all** of them, and `build-check` goes **RED** — the template's own scanner then rejects the image the template itself recommends, without this line.
- **The base image is bumped automatically**: Renovate auto-detects the `Dockerfile`'s `FROM` as soon as it lands — **nothing to declare**. *(Without a bot bumping it, Trivy would block PRs on an image CVE with nothing proposing the fix — the control detects, nobody fixes. Renovate closes that hole by construction.)*
- **Don't touch the `## Branching` block** or create `develop`: with no host to validate, that would be an empty ritual.
- Once the workflow is on `main`, rerun `configure-repo.sh`: it detects `docker-publish.yml`, requires `build-check`, sets the `tags` ruleset and immutable releases, and **verifies the image is anonymously pullable**.
- **The ghcr package can be private even if the repo is public** *(see "Version pin in production")*: on a personal account it's pullable by default; on an org, it may need a manual step (UI, no API) — only make it public if the test fails.
- **Immutable releases: before v1**, never after — they aren't retroactive.
- Document self-hosting in the README with a **pinned tag, never `:latest`**.

### Acquiring `--staging` — "a host has appeared, I want to validate it before prod"

*(Exact sequence: RUNBOOK §5.)* The `## Branching` block in `CONTRIBUTING.md` **and** in `AGENTS.md` must be rewritten for 3 stages — otherwise both still advertise GitHub Flow even though `develop` exists. Pushing `develop` goes through fine: the `pre-push` hook lets branch **creation** through. Once `develop` is detected, `configure-repo.sh` sets its ruleset and **allows merge commits** on `main` — squash-only is **incompatible** with a staging branch. `docker-publish.yml` already listens for PRs to `main` **and** `develop`: without that, a PR to `develop` would stay blocked forever.

### Acquiring / removing `--pages`

**Acquiring**: copy `pages.yml`, fill in the `<web-dir>`, and create the site *(`configure-repo.sh` does it — `Pages: write`)*. No required check is added → **no lockout risk**, order is free.
**Removing**: delete `pages.yml`. **Never** leave it running "just in case" — **an orphaned workflow is a control nobody reads anymore**.

### Removing a capability — the reverse direction

It only **removes** controls: no lockout risk… **except one**, symmetric to the ordering pitfall described above ("the order is the trap").
⚠️ **Remove `build-check` from the required checks BEFORE deleting `docker-publish.yml`.** The other way around, the check stays required while nothing produces it anymore → **every PR is blocked forever**.
