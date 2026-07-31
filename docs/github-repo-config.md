# GitHub repo configuration — reference

> **One-shot** complement to the standard (`claude-code-project-standard.md` ; auth = §5).
> What gets set **once** when a repo is created, + the PAT model.
> ⚠️ **Nominal cycle: repo created PRIVATE, then flipped PUBLIC.** `configure-repo.sh` is therefore run **twice**: at creation (it sets what the Free plan allows) then **at the flip** (it sets the rest — rulesets, secret scanning, Pages). It is **idempotent**: that's by design.
> **The model: one TOOLCHAIN + three CAPABILITIES.** A rigid archetype ("static" vs "Node/Docker")
> would merge three **independent** questions, and would break as soon as one steps outside it — *a page hosted
> outside Pages, or a Pages page also packaged as an image for self-hosters*.
>
> | | What it decides | Values |
> |---|---|---|
> | **Toolchain** (`--type`) | **only** which `ci.yml` | `static` (no npm) · `node` (npm, tests, types) |
> | **Capability `pages`** | the site is served by **GitHub Pages** | `pages.yml` |
> | **Capability `artefact`** | the repo **publishes an image that SOMEONE ELSE deploys** | `docker-publish.yml` · Trivy · tags ruleset · immutable releases · **public** ghcr package |
> | **Capability `staging`** | there is a **host to VALIDATE** before prod | `develop` branch · `develop` ruleset · 3-stage flow |
>
> 🔴 **`develop` follows from STAGING, never from Docker or the language.** A `node` project with no host to validate **does not** have one. Nor does a static site that publishes an image. *(Standard §12.)*

## 1. Security & code controls — what to enable, where

### Baseline — EVERY repo, no exception
| Control | Setting | When |
|---|---|---|
| **`gitleaks`** | **`pre-commit` hook** (staged files) **+ CI on the FULL history**. **Never optional**: it's the **only** anti-secret net during the whole private phase (no server-side secret scanning on Free). Pinned binary + checksum — **not** `gitleaks-action`, which requires a **license** on an ORG repo. | commit + every PR |
| **`semgrep`** | static analysis of **application code** (`p/security-audit`, `p/owasp-top-ten`, `--exclude=.github`). Exists because **CodeQL is unavailable on private** — it **precedes** it, doesn't replace it (file-by-file analysis). | every PR |
| **`osv-scanner`** | vulnerable dependencies (all manifests, `-r .`, OSV database). **The equivalent of `dependency-review`, which does work on private.** | every PR |
| **`actionlint` + `zizmor`** | workflows are code: a `${{ }}` in a `run:` is a **shell injection**. | every PR |
| **CodeQL** | native **default setup**, enabled by `configure-repo.sh` (`PATCH /code-scanning/default-setup`, `Administration: write`). **Detects languages and KEEPS THEM UP TO DATE on its own** — the previous `codeql.yml` declared only ONE, and missed `actions` workflows (§17). **Unavailable on private** (GHAS) → arrives at the flip. The two modes are **mutually exclusive**. | push/PR `main` + weekly |
| **Dependabot alerts** | **CVE detection** — native, free even on private, **everywhere**: it's the dependency graph that Renovate reads. Version updates → **Renovate**. **Security updates**, though, are only the safety net **at 2 stages** — at 3 stages their PRs would target `main` and bypass staging *(→ standard, "Who updates dependencies")*. | continuous |
| **Renovate** | **only update bot.** Auto-detects **all** the repo's ecosystems (npm, docker, actions, pip…) **with no declaration at all**, + the 4 pinned VERSION+SHA256 binaries (gitleaks, actionlint, osv-scanner, trivy). Reads Dependabot alerts (`vulnerabilityAlerts`) for its security PRs. Routine = PR reviewed by a **human**; **security = auto-merge**. Minor/patch grouped. | continuous / weekly |
| **Secret scanning + push protection** | native, free on **public** (unavailable on private/Free). | every push |
| **`main` ruleset** | PR required · required checks (**`checks`** + CodeQL + **`build-check` if `artefact` capability**) · no force-push/delete · no bypass · `required_approving_review_count = 0` (solo). | continuous |
| **`tags` ruleset + immutable releases** | a `v*` tag that can be neither moved nor deleted, non-replaceable assets. **Without both, the prod pin of §13 is worth NOTHING.** | continuous |
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
| **Docker hardening** | base image pinned by SHA256 **digest** · runtime **with no package manager** (§14) · `tmpfs` `noexec,nosuid,nodev,size=` · healthcheck · `:latest` blocked on pre-release. |
| **PUBLIC ghcr package** | 🔴 Default depends on the **owner**: **personal** account → pullable anonymously (**HTTP 200**) ; **organization** → private by default (**403**), no one can self-host. `configure-repo.sh` **tests the anonymous pull** and only asks for the action if the test fails. **Detail, test provenance, UI procedure: §4 "ghcr package visibility".** |

### In addition — `staging` CAPABILITY
| Control | Setting |
|---|---|
| **`develop` ruleset** | the requirements of `main`, **minus two, by design**: ❌ no `code_scanning` *(CodeQL only analyzes `main` — requiring it here would block every PR on a check that will never arrive)* · ❌ **squash ONLY** *(the merge commit is reserved for `main`, for promotions)*. |
| **Merge commit allowed on `main`** | squash only is **incompatible** with a staging branch. |
| **Back-merge `main` → `develop`** | consequence of the two lines above: the only route is a **squashed PR** *(a direct push runs into the `pull_request` rule, a merge commit into squash-only)*. ⚠️ **GitHub's message names the wrong culprit** — *"Merge commits are not allowed on this repository"* is shown even though the repo allows them *(`allow_merge_commit=true`)*: it's the **rule** that blocks, not the repo's setting. Looking in the settings is a dead end. |

> **Plan note**: on a personal account (non-org), public secret scanning only has the **default patterns** — no custom regex nor validity checks (reserved for GitHub Secret Protection, paid/org). Hence the value of gitleaks for non-standard secrets.

## 2. PAT permissions — two tiers

> 🎯 **To EXECUTE** (create the token, check the boxes) → **`RUNBOOK.md` §1**, which carries the ready-to-use tables
> and **is authoritative**. **This section explains WHY** each permission is there:
> it is **derived from the endpoints called**, never discovered by trial and error.
> **It must never be discovered by trial and error**: every missing permission
> **fails SILENTLY** — everything else passes, and the missing control doesn't show.

Mirror of one-shot/recurring: **the assistant handles all the recurring work autonomously; the one-shot admin stays manual (the maintainer)**.

| RECURRING → assistant PAT (fine-grained, 1 repo) | ONE-SHOT → the maintainer (Administration: write) |
|---|---|
| Contents: **write** | Enable the security features (secret scanning, push protection ; **Dependabot alerts ON** everywhere, **security updates ON at 2 stages only** ; Renovate adds security auto-merge) |
| Pull requests: **write** | Create/edit rulesets & branch protection |
| Issues: **write** | `PATCH /repos`: visibility, merge-methods, delete-branch, topics, homepage |
| Actions: **read/write** (re-run/cancel runs) | Enable **CodeQL default setup** *(`configure-repo.sh` does it)* |
| Dependabot alerts: **write** (dismiss/reopen) | Dependabot **secrets** (values), webhooks, deploy keys |
| Code scanning alerts: **write** (dismiss) | 2FA (**account** setting, not repo — UI/mobile only) |
| **Secret scanning alerts: read** — dismiss reserved for the maintainer (wrongly rejecting a real leak = too much impact) | |
| **Administration: read** *(NEVER write)* — what a `✓` claims must be **VERIFIED**: `GET /automated-security-fixes` · `GET /vulnerability-alerts` · `GET /branches/{b}/protection` | |
| Metadata: read (implicit) · **Workflows: write** — the assistant edits the CI YAML | |

**Verified**: handling (dismiss/reopen) a Dependabot or code scanning alert **only** requires the dedicated permission in *write* — **no Administration**. Opening a PR = Contents + Pull requests write ; merging = Contents write.
The PAT keeps the **uniform permissions** from standard §5 (`Metadata R`, `Contents R/W`, `PR R/W`, `Issues R/W`, `Workflows R/W`, `Actions R/W`) **+** the 3 alerts above **+ `Administration: read`**. **`Administration: write`: never.**

#### `Administration: read` — why one more permission, and why that one

**It mutates nothing.** What makes `Administration` formidable *(deleting the repo, flipping visibility, rewriting a ruleset)* is in the **write**, reserved for the ephemeral admin PAT.

It closes a **verification** gap, derived from three endpoints that no other permission opens:

| Read | Otherwise |
|---|---|
| `GET /automated-security-fixes` · `GET /vulnerability-alerts` | the state of the security toggles is **not readable**: the only check is a screenshot from the maintainer |
| `GET /branches/{b}/protection` *(+ `/required_status_checks`)* | **CLASSIC** protection stays invisible — the `rulesets` API doesn't show it, and it can lock `main` **forever** |

🔴 **The underlying reason: a `✓` printed by a script is not an applied setting.** A `--dry-run` once announced 3 settings, of which **2 were impossible**, and classic protection once blocked every PR on a repo, CI green. Without reading, these two failures are **structurally undetectable** by the assistant — leaving autonomous security maintenance to fall back on the maintainer.

> 🔴 **`Checks` is NOT in this list — and CANNOT be.** Documented by GitHub, **absent from the UI** of fine-grained PATs → `gh pr checks` and `gh pr view` fail (they read `statusCheckRollup`). CI green is verified via `gh run list --commit <sha>` (`Actions: read`, already there) instead. **Detail, citations, exact command, the false-green trap: standard §18.**

> **One-shot admin — EPHEMERAL token, no dormant token**
>
> The Administration PAT lives **nowhere**: not in the keychain, not in `.envrc`, not in shell history.
> **Created → used → revoked**, within minutes. `configure-repo.sh` asks for it as **masked input**.
>
> - Fine-grained · **"Only select repositories" = THIS repo** → blast radius **1 repo**. **Complete** recipe, one permission per endpoint called *(verified against the REST doc "Permissions required for fine-grained PATs" — derived from the endpoints, **NEVER** discovered by trial and error)*:
>
>   | Permission | Level | Why |
>   |---|---|---|
>   | **Administration** | **write** | `PATCH /repos` (merge, description, homepage) · `PUT /vulnerability-alerts` · `*/rulesets` · `PUT /immutable-releases` *(same permission — nothing to add to the recipe)* |
>   | **Pages** | **write** | `POST`/`PUT /pages` — site creation, source = workflow |
>   | **Code scanning alerts** | **read** | `GET /code-scanning/analyses` — knowing whether CodeQL has run |
>   | **Actions** | **read** | 🔴 `GET /actions/runs/{id}` — **track the run of the 1st CodeQL analysis**. Without it, the script doesn't know when it finishes → it **doesn't set the `code_scanning` rule**, and **`main` stays UNGUARDED**. |
>   | **Contents** | **read** | `GET /contents/…` — detecting `pages.yml` (private repo) |
>   | **Issues** | **read** | `GET /repos/{o}/{r}/issues` — dating Renovate's *Dependency Dashboard* (proof of life before removing the Dependabot safety net) |
>   | **Metadata** | read | implicit |
>
>   ⚠ **`Administration` IS NOT ENOUGH**, and **every missing permission fails SILENTLY**: everything else passes, and the missing control doesn't show.
>   ⚠ The `enablement: true` of `actions/configure-pages` **does not compensate for** the absence of `Pages: write`: a workflow's `GITHUB_TOKEN` doesn't have that right → Pages site creation fails on **every** deployment.
> - Sufficient: **all** of the script's calls are **repo-level** (`PATCH /repos/{o}/{r}`, `PUT …/vulnerability-alerts`, `POST …/rulesets`). No account-level right is required.
> - **Repo creation**, though, requires an account-scoped right: it is therefore done **in the UI** (30 s, a few times a year) — which simply removes the need for a broad token.
>
> **Why not a single PAT that has `Administration` removed afterwards**: that would give the assistant, for the duration of the config, the right to **change visibility** or **delete the repo** — and removing the permission would be **manual, so forgettable**, leaving a token alive for 90 days. Revoking a disposable token is **binary**; downgrading its rights is not.
>
> **The assistant NEVER has `Administration: write`.** `configure-repo.sh` is run by the maintainer.

## 3. OpenSSF Scorecard — keep / drop (solo, public, small)

- **Keep** (~zero cost): Token-Permissions · Branch-Protection · Pinned-Dependencies · Dangerous-Workflow (no `pull_request_target` + PR checkout) · Security-Policy (`SECURITY.md`) · SAST (CodeQL) · Dependency-Update-Tool (Renovate).
- **Drop** (overkill solo): Signed-Releases · Fuzzing · CII-Best-Practices badge · signed commits (friction with no gain against oneself).
- **2FA**: yes, non-negotiable — but an **account** setting, enabled in the UI.

## 4. Setup — scriptable vs UI (for `configure-repo.sh`)

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
| **Dependabot security updates** *(the safety net — **2 stages only**: at 3 stages, `DELETE` on the same endpoint, cf. §"Who updates dependencies" of the standard)* | `gh api -X PUT repos/{o}/{r}/automated-security-fixes` — 🔴 **DEDICATED endpoint, NOT a sub-key of `security_and_analysis`**: `dependabot_security_updates` is in the GET's **response** schema, **not** in the PATCH's body params. Passing it to the PATCH **raises no error** — it is ignored, **silently**. |
| Rulesets | `gh api -X POST repos/{o}/{r}/rulesets --input ruleset.json` (`gh ruleset` = read-only) |
| Topics / homepage / merge-methods / delete-branch | `gh repo edit --add-topic … --homepage … --enable-squash-merge --delete-branch-on-merge` |
| Renovate · gitleaks · npm audit · CI updates | **committed files** (`.github/renovate.json`, `.github/workflows/*.yml`), no API |
| 2FA | **UI-only** (no endpoint) |
| **Reading the packages / ghcr API** | ❌ **IMPOSSIBLE on fine-grained** — GitHub Packages is **not supported** by fine-grained PATs (classic `read:packages` only). There is no point adding the permission: **it doesn't exist**. → **Moot**: the right test is an **ANONYMOUS pull** of the registry (`ghcr.io/token` + `/v2/<img>/manifests/<tag>` → **200 = pullable**), which verifies *exactly* what the prod host does, **with no token at all**. Set by `configure-repo.sh`. |
| **ghcr package visibility** | ⚠️ **UI, no API** *(fine-grained PATs do NOT cover ghcr — only `classic` PATs do)*. 🔴 **The default DEPENDS ON THE OWNER, and confusing it is costly:** on a **PERSONAL** account, a package published from a **public** repo is pullable **anonymously, WITH NO ACTION AT ALL** *(HTTP 200 — verified on test003)*. On an **ORGANIZATION**, it is **PRIVATE by default** → an anonymous `docker pull` = **403**, and **no one can self-host** *(verified on test004)*. → **`configure-repo.sh` TESTS the anonymous pull** and only asks for the action **IF the test fails**. *(Org-wide: Settings → Packages → Package creation → default visibility.)* **When the action IS needed** *(org)*: Package settings → Danger Zone → *Change visibility* → **Public**. Without it, neither the prod host nor a user can pull the image — and **the production version pin is worth nothing anymore**: it points to an image no one can retrieve. |
| **Reported content** (moderation) | **UI-only — NO API** (verified: no moderation endpoint exists). Exact path, scope (org only) and item count: **§5, point 6**. ⚠️ The box **is not checked** on "All users". |

> **Dry-run first**: on a personal account, some `security_and_analysis` sub-keys (`advanced_security`, `code_security`) are probably no-ops outside GHAS/org. This should be tested on the target repo before hard-coding it into `configure-repo.sh`.

## 5. New repo checklist (created private → flipped public)

0. **Choose the toolchain and the capabilities** — *the three questions, in this order*:
   **(a)** is the site served by **Pages**? → `--pages` · **(b)** does the repo **publish an image that someone ELSE deploys**? → `--artefact` · **(c)** is there a **host to VALIDATE** before prod? → `--staging`.
   Then: `./init-project.sh <project> <owner/repo> [--type static|node|generic] [--pages] [--artefact] [--staging]`.
   *Shortcuts: `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging` · `--type generic` ≡ no capability (any other toolchain — security controls only, build/test to be filled in).*
1. Create the repo — **PRIVATE** (the nominal case), remote as a **bare URL**, 1-repo PAT in `.envrc` (standard §5) — with the **3 alert permissions** from §2.
2. `configure-repo.sh`: rulesets (`main` · `develop` **if staging** · `tags`) · secret scanning + push protection · **Dependabot alerts + security updates** *(safety net **at 2 stages only** — Renovate adds security auto-merge ; at 3 stages their PRs would target `main` and bypass staging)* · **immutable releases** · topics · homepage · delete-branch-on-merge *(**removed** if 3-stage flow **without** a ruleset — on private Free, it would delete `develop` at the 1st promotion)* · **merge method depending on the `staging` capability** — squash only, **+ merge commit if `develop` exists** *(squash only is incompatible with a staging branch)*. *(**CodeQL is included**: the script enables the **default setup**, waits for the 1st analysis, then sets the `code_scanning` rule. There is no more `codeql.yml`.)*
3. Files present from the 1st commit: `LICENSE` · `README` (dual-target, standard §15) · `SECURITY.md` (private advisories) · `CONTRIBUTING.md` · `CODE_OF_CONDUCT.md` · `.github/` (CI, `renovate.json`, `ISSUE_TEMPLATE/` + `config.yml`, PR template) · `.gitattributes` if a vendored lib.
4. **Before going public**: `gitleaks detect` on the **full history** (not just HEAD) — a secret in an old commit leaks at the visibility flip.
5. Enable account **2FA** (UI).
6. **ORG repos only** — *"Repository admins accept content reports"*: Settings → **Moderation options** → **Reported content** → **"Prior contributors and collaborators"** (UI, **no API**).
   ⚠️ **This item exists ONLY on repos belonging to an organization** ([GitHub changelog, 2020](https://github.blog/changelog/2020-06-23-community-content-reports-included-in-community-profile/)): an org repo's checklist counts **8 items**, a personal account's **7**.
   **Consequence not to miss**: a personal repo at 100% and an org repo at 87% can have **exactly the same files** — comparing their scores makes no sense.

> **License**: **PolyForm Noncommercial 1.0.0** by default (`templates/repo/LICENSE`) — attribution required, noncommercial use allowed, commercial use closed, **including partial use**. Year and holder are substituted by `init-project.sh`, nothing to fill in.
> 🔴 **It is NOT open source** *(the OSI definition forbids restricting the field of use)*, and GitHub displays it as **"Other"**. A repo aimed at professional users, or meant to be adopted widely, wants a permissive license instead — **swapping `LICENSE` is a one-file decision**, and it is the right moment to make it: before the first release, not after.
> **`LICENSE-MIT` stays whatever the project chooses**: the files inherited from the template are MIT so that a generated project never inherits a restriction from the tool that built it.
> BEFORE locking it in — check: (1) no dependency nor vendored code under copyleft (GPL/AGPL) imposing something stricter; (2) does this project have a commercial future, in which case noncommercial is the wrong default?; (3) when in doubt, ask the maintainer.

> Sources: GitHub Docs (code scanning, Dependabot, secret scanning, REST repos/rulesets/alerts) · OpenSSF Scorecard `docs/checks.md`.
