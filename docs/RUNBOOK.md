# Runbook — the lifecycle of a project, end to end

> **This document states the ORDER OF ACTIONS and WHO performs them. The standard states the WHY.**
> Each step refers to the section that explains it — the reasoning is not copied here.
>
> 🔴 **SOURCE OF TRUTH — the PAT permission tables (§1) ARE AUTHORITATIVE.** They are *also* in `secrets-and-auth.md`, which explains **where each permission is derived from** (a called endpoint = a permission). **In case of discrepancy: this document wins, and the discrepancy is a DEFECT to fix** — two copies always diverge, and a missing permission **fails SILENTLY**.
> Standard: `claude-code-project-standard.md` · Secrets & auth: `secrets-and-auth.md` · Controls, branches & repo config: `repo-controls.md` · Updates: `security-and-updates.md`

**Two rules that run through the entire document:**

| | |
|---|---|
| 🔴 **The assistant NEVER has `Administration: write`** | Everything touching rulesets / visibility / Pages / secret scanning is **done by the maintainer**, with an **EPHEMERAL admin PAT** created then **revoked immediately after**. |
| 🔴 **The nominal cycle is: PRIVATE → developed → PUBLIC** | A private repo on the Free plan has **neither ruleset, nor secret scanning, nor CodeQL**. The checks **run** but **nothing requires them**. The flip activates **all of them at once**. |

---

## 1 · Create a project

**Ask the three questions BEFORE typing the command** — they decide everything *(`repo-controls.md`)*:

| | Question | Flag |
|---|---|---|
| **a** | Will the site be served by **GitHub Pages**? | `--pages` |
| **b** | Will the repo **publish an image that someone ELSE deploys**? *(self-hosters, NUC…)* | `--artefact` |
| **c** | Is there a **host to VALIDATE** before prod? | `--staging` |

> **`develop` follows from (c) alone** — never Docker, never the language. Full rule: `repo-controls.md`, "The 3 CAPABILITIES".

### 🔴 Step 1 — the maintainer: create the repo (UI)

**→ https://github.com/new**

- **Visibility: PRIVATE.** *(The nominal cycle. It will go public later — §4.)*
- **Check nothing**: no README, no .gitignore, no license. `init-project.sh` sets them up, and a file created by GitHub would make the first commit diverge.

### Step 2 — Claude: generate the project

```bash
./init-project.sh <project> <owner>/<repo> [--type static|node|generic] [--pages] [--artefact] [--staging]
```

Creates the tree, the first commit, the remote as a **bare URL**, and an **EMPTY `.envrc`** *(the PAT does not exist yet)*.

> ⚠️ `repo/.envrc` **does not exist** until this script has run: nothing to paste into it before step 3.

### 🔴 Step 3 — the maintainer: create the write PAT (the assistant's)

**→ https://github.com/settings/personal-access-tokens/new**

| Setting | Value |
|---|---|
| **Token name** | `claude-<repo>` |
| **Expiration** | **90 days** *(Claude alerts at D-14 — §6)* |
| **Resource owner** | the repo's owner *(personal or the org)* |
| **Repository access** | ⚠️ **Only select repositories → THIS repo, and only this one.** *Blast radius = 1 repo.* |

**Repository permissions** — *exactly these, nothing more*:

| Permission | Level | Why |
|---|---|---|
| **Contents** | Read and write | push, branch, merge |
| **Pull requests** | Read and write | open and merge PRs |
| **Issues** | Read and write | |
| **Workflows** | Read and write | edit the CI YAML |
| **Actions** | Read and write | rerun / cancel a run |
| **Dependabot alerts** | Read and write | handle alerts **autonomously** |
| **Code scanning alerts** | Read and write | same |
| **Secret scanning alerts** | **Read** *(not write)* | 🔴 **dismissing is reserved for the maintainer** — wrongly dismissing a real leak has too much impact |
| **Administration** | **Read** *(NEVER write)* | **verify** the security settings that a script's `✓` claims — derivation: `secrets-and-auth.md` |
| *Metadata* | *Read* | *checked automatically* |

> 🔴 **`Administration: WRITE`: NEVER** — that is the entire security matrix, and it remains the sole preserve of the **ephemeral admin PAT** *(§ next)*. **`read` is admitted, and only that.** **Everything else: No access.**
> ⚠️ **On a PAT ALREADY created, adding it requires NO rotation**: the UI edits the permissions of an existing fine-grained token *(→ https://github.com/settings/personal-access-tokens)*.

### 🔴 Step 4 — the maintainer: paste the PAT, then **`direnv allow`**

```bash
cd <project-folder>/repo
$EDITOR .envrc          # fill in the line: export GITHUB_PAT=github_pat_xxxxx
direnv allow            # ⚠️ MANDATORY — see below
```

> 🔴 **`direnv allow` is NOT optional, and the trap is subtle.**
> `init-project.sh` already did a `direnv allow` — **but on an EMPTY `.envrc`**. **Pasting the PAT into it modifies the file**, and direnv **automatically revokes** its authorization *(that is its security: it refuses to run a modified file without explicit consent)*.
> **Without this second `direnv allow`, `.envrc` is never loaded** → `GITHUB_PAT` stays empty → **`git push` fails with 403**, even though the token is indeed in the file. **A perfectly confusing symptom.**

**Verify that it took effect** *(the PAT must NEVER be displayed — only a boolean is tested)*:
```bash
cd <project-folder>/repo && [ -n "$GITHUB_PAT" ] && echo "PAT loaded ✓" || echo "PAT ABSENT ✗ → direnv allow"
```

- **Never in `.env`** *(container leak via `env_file`)*. **Never in the remote URL** *(leaks in clear text in `.git/config`)*.
- *(If `direnv` is not installed: `brew install direnv` + the hook in `~/.zshrc`.)*
- 💡 **Claude's Bash tool launches a NON-interactive shell: direnv does not run there.** `init-project.sh` therefore set up a **local credential helper** that reads `$GITHUB_PAT` — that is what lets the assistant push despite this. **The maintainer's `direnv allow` remains essential**: it is what puts the PAT into the environment.

### Steps 5 and 6 — Claude

| # | Action |
|---|---|
| 5 | **Fill in what the script flags**: `<contact>` in `SECURITY.md` · the fields of `AGENTS.md` · the holder of `LICENSE`. |
| 6 | First push: `git push -u origin main` *(the `pre-push` hook allows the **creation** of a branch)*. Then `git push -u origin develop` **if `--staging`**. |

### 🔴 Step 7a — the maintainer: create the **EPHEMERAL** ADMIN PAT

**→ https://github.com/settings/personal-access-tokens/new**

| Setting | Value |
|---|---|
| **Token name** | `admin-<repo>-disposable` |
| **Expiration** | **the shortest possible** *(7 days)* — it will be **revoked within 5 minutes** anyway |
| **Repository access** | ⚠️ **Only select repositories → THIS repo** |

**Repository permissions** — *the COMPLETE recipe, derived from the endpoints called*:

| Permission | Level | Why |
|---|---|---|
| **Administration** | **Read and write** | `PATCH /repos` · `PUT /vulnerability-alerts` · `*/rulesets` · `PUT /immutable-releases` |
| **Pages** | **Read and write** | creation of the Pages site |
| **Code scanning alerts** | **Read** | know whether CodeQL has produced an analysis |
| **Actions** | **Read** | 🔴 **track the run of the 1st CodeQL analysis.** Without it, the script does not know when the analysis finishes → it **does not set the `code_scanning` rule**, and `main` remains **UNGUARDED**. |
| **Contents** | **Read** | detect `pages.yml` / `docker-publish.yml` · read `CONTRIBUTING.md` *(does the repo publish 3 tiers?)* |
| **Issues** | **Read** | 🔴 **proof of life for Renovate** — `GET /repos/{o}/{r}/issues`, to date its *Dependency Dashboard* before removing the Dependabot safety net from a 3-tier flow. Without it, the script **keeps** the safety net *(its security PRs will keep targeting `main`)* — it says so and names this permission. *(The official table lists this endpoint under `Issues: read` **and** under `Pull requests: read` — one **or** the other suffices; `Issues` is the one used here, it is what gets read.)* |
| *Metadata* | *Read* | *automatic* |

> ⚠️ **`Administration` IS NOT ENOUGH** — every missing permission in the table above fails **silently**: why, and how the recipe is derived, in [`secrets-and-auth.md`](secrets-and-auth.md#pat-permissions-two-tiers).
> **This token is stored NOWHERE**: no keychain, no `.envrc`, no shell history. The script requests it as **masked input**.

### Step 7b — the maintainer: run the script

```bash
cd ~/Documents/Claude/template/repo
./configure-repo.sh <owner>/<repo> '' 'One-line description of the project.' 'topic-a,topic-b'
#                                   ↑ homepage: empty here, the script will derive it from Pages at the flip
#                                                                            ↑ topics: csv, optional
```

> 🔴 **On a repo that ALREADY EXISTED, the script may report a "CLASSIC branch protection still active".** This is the **old** protection system, which the `rulesets` API **does not show** — and it **stacks** with the ruleset. If it requires a check named after a job that has disappeared *(which happens as soon as the template's workflows are adopted)*, **no PR can ever be merged again**, whether CI is green or not, with only the message "base branch policy prohibits the merge".
> **→ Remove it NOW** *(the ruleset was just set: the branch is never without protection)*: https://github.com/&lt;owner&gt;/&lt;repo&gt;/settings/branches — section **"Branch protection rules"**, to be distinguished from the **"Rulesets"** section just below. *(The "Protected" badge lights up for both: look at the SECTION, not the badge.)*

> **The description AND the topics require `Administration:write`** — the assistant, which **never** has this permission, receives a **403**. **Only this script can set them.**
> Without a description, community health **caps at 85%**. Without a topic, the repo **does not surface in any GitHub search by subject**. The script **flags it** in both cases instead of letting the gap slip through.

The script **requests the PAT as masked input** *(it appears neither on screen, nor in history, nor in `ps`)*.

> 🔴 **A successful run does NOT end the step.** The admin PAT is still alive, and it can delete the repo and change its visibility — **step 7c below revokes it, and it is never optional.**
> *(Measured 2026-08-06: read alone, this block led to the conclusion that configuration was over once the script had run.)*

- **On a PRIVATE/Free repo, it sets what it can**: **Dependabot alerts** *(everywhere — Renovate reads them)*, **security updates** *(safety net — **2 tiers only**)*, description, merge method, `default_workflow_permissions`.
- 🔴 **On a 3-TIER flow, RE-RUN it once the Renovate app is installed.** The script only removes the Dependabot safety net *(whose security PRs target `main`, short-circuiting staging)* on seeing Renovate **alive** — its *Dependency Dashboard* dated less than 14 days old. Run **before** onboarding, it finds no dashboard, **keeps** the safety net and **says so**: this message is an invitation to re-run it, not a failure.
- **It announces that rulesets / secret scanning / CodeQL are unavailable** — **this is EXPECTED, not a failure**: they arrive at the flip *(§4)*.
- ⚠️ **The description must not contain any control character** *(the API returns 422)* — the script removes them and flags it. **Also avoid em dashes stuck together from a copy-paste.**
- 💡 **`--dry-run`**: reads everything, **writes nothing**. To use on a **live** repo when unsure.
- 🔴 **None of the above ends the step.** Whatever the script reports, the admin PAT is still alive and step 7c revokes it — **the run is not the end, the revocation is.**

### 🔴🔴 Step 7c — the maintainer: **REVOKE THE ADMIN PAT. NOW.**

**→ https://github.com/settings/personal-access-tokens**

> **This is the step that gets forgotten, and it is the most dangerous one to forget.**
> This token can **delete the repo** and **change its visibility** — it has **no reason left to exist** once the script has finished. *(Why revoke rather than downgrade → §7 below.)*
>
> *(The script repeats this reminder at the end of its run — **a reminder is not a revocation**.)*

### Step 8 — the maintainer: install Renovate

**→ https://github.com/apps/renovate** — *"Install" → Only select repositories → this repo.*

> **Without it, `renovate.json` is INERT**: the 4 pinned binaries *(gitleaks, actionlint, osv-scanner, trivy)* **freeze silently** *(why this matters: `security-and-updates.md`)*.

> 🔴 **THE ORDER IS A TRAP — `renovate.json` MUST be on `main` BEFORE the app is installed.**
> Renovate checks whether it finds a config on the default branch.
> **It finds one → it gets to work directly.**
> **It does not find one → it opens an onboarding PR "Configure Renovate".**
>
> Here, the order is correct **by construction**: the template puts `.github/renovate.json` in place as early as step 1, so at step 8 the file is already on `main` — **no onboarding PR appears**.
>
> **⚠️ On an EXISTING repo** *(bringing into compliance, §7)*, **the order reverses on its own**: the app is often installed before the file arrives → **the onboarding PR shows up**.
> 🔴🔴 **NEITHER MERGE IT NOR CLOSE IT — LEAVE IT OPEN and ask the maintainer.** Both are wrong, and they are not equally wrong: merging only activates Renovate's **DEFAULT** config instead of the template's **tuned** `renovate.json`, whereas **closing is the bot's DOCUMENTED OPT-OUT** and silently disables the repo.
> *(The two interdictions are stated in one sentence on purpose: read alone, a bare "never merge it" reads as an invitation to close — measured on 2026-08-06, an agent given that line and nothing else concluded exactly that.)*
> **What Renovate's own documentation says — quoted here as the TRAP, never as the instruction:** *"If you wish to opt-out of having Renovate run for your repo, simply close the onboarding Pull Request without merging it."* **That sentence describes how to DISABLE the bot. It is not what to do here.**
> The `disabled` status lives **on Mend's side, not in the repo**: **committing `renovate.json` afterward reactivates NOTHING.**
> **Experienced on 14/07/2026** — the 4 onboarding PRs closed on that instruction left **4 repos** `disabled`, **6 days without a single job**, and one of them **with no update bot left at all** *(the full-Renovate switch had just removed its `dependabot.yml`, betting on a bot that was not running)*.
> ✅ **Course of action: LEAVE IT OPEN and ask the maintainer.** Never close it by reflex.
> **Fix if this has already happened** *(proven on a real repo on 21/07)*: a **manual scan from the Mend portal** *(developer.mend.io)* switches the repo back to `onboarded` — a **UI action by the maintainer**. The Dependency Dashboard reopens, and Renovate itself cleans up the phantom `renovate/configure` branch.
> **The sign that a bot is ALIVE** = a recent job **AND** a Dependency Dashboard. A config file proves nothing.

### Step 9 — the maintainer, **if the repo has an npm tree**: enable Dependabot malware alerts (UI)

> **npm-only · NO API → `configure-repo.sh` CANNOT set it** *(see §7)*. Available **from private Free onward** *(not gated by the plan)*.
> **→ Settings → Advanced Security → *Dependabot malware alerts* → Enable.**
> Detects **malicious** npm versions *(compromised package, typosquat)* — an angle that **Renovate does not cover**: Renovate remedies **CVEs** by version bump, but a malicious package often has **no safe version** to bump to. **Useless on a repo without `package.json`.**

---

## 2 · Working day to day

**`main` is production. Nothing is ever written to it directly.** *(`repo-controls.md`)*

```bash
git switch -c feat/<subject>          # from `develop` if --staging, otherwise from `main`
git commit                          # the pre-commit hook REFUSES a secret
git push -u origin feat/<subject>     # the pre-push hook REFUSES main/develop
gh pr create --fill

# Is the CI green? (see the warning below — NOT `gh pr checks`)
sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
gh run list --commit "$sha" --json workflowName,status,conclusion

gh pr merge --squash                # ONLY if all expected workflows are completed/success
```

> 🔴 **In PRIVATE, nothing requires CI.** No ruleset → GitHub **would accept** the merge of a red PR. *(Why this one gesture stays human, and where the rule is written for agents: `repo-controls.md`.)*
>
> **Green ⇔ every expected workflow is `completed / success`** — the exact set, and why a missing workflow is not a green: [`AGENTS.md`](../AGENTS.md#discipline-pr-only).

> 🔴 **Do NOT use `gh pr checks <n>`** *(nor `gh pr view <n>` alone)* — the `Checks` permission both need cannot be granted on this standard's PAT: full explanation in [`secrets-and-auth.md`](secrets-and-auth.md#writing-push-pr-issues-1-repo-fine-grained-pat-exposed-by-direnv).
> **Nothing to add to the PAT**: the command above only needs `Actions: read`, already in the matrix. *(`gh pr view --json headRefOid` works: by targeting one field, it no longer requests the rollup.)*

**With `--staging`**: `feat/` branches accumulate in `develop`. `develop → main` happens **only when publishing a version** — **a single PR for N changes**, not two PRs per change.

---

## 3 · Publish a version

| # | Who | Action |
|---|---|---|
| 1 | Claude | *(if `--staging`)* PR `develop → main` — **opened on the maintainer's instruction, like every pull request** *(`AGENTS.md`)* — then green CI, merge **as a merge commit** *(never squash — `repo-controls.md`)*. ⚠️ **THEN: see the box below — this merge DELETES `develop` as long as the repo is private.** |
| 2 | Claude | `git tag vX.Y.Z && git push origin vX.Y.Z` → the **Release** is created, and the **ghcr image** pushed *(if `--artefact`)*. ⚠️ **With `--artefact`, the Release is the `release` job of `docker-publish.yml`** *(`needs: build-push` — no Release if the image was not published)*; **without** this capability, it is `release.yml`. **Only one of the two exists**, never both. **Both build the note with `./release-notes.sh <tag>`** — nothing is written for the occasion *(`METHODE.md`)*. ⚠️ **A repo with NEITHER workflow** *(this one)* **creates the Release by hand, and the note the same way**: `gh release create vX.Y.Z --title vX.Y.Z --notes-file <(./release-notes.sh vX.Y.Z)`. |
| 3 | Claude | **THEN** seal `CHANGELOG.md`: `Unreleased` becomes `## [X.Y.Z] - <date>`, and `.claude-plugin/plugin.json` gets the same number. Through a pull request — **opened on the maintainer's instruction** — **and only now can it be green.** |

> 🔴 **THE TAG COMES FIRST, THE SEALING SECOND. Doing it the other way round cannot be merged.**
> `verify-version.sh` compares the CHANGELOG's newest **versioned** heading to the newest **tag**
> *(`Unreleased` is skipped — it is the open section)*. Sealing first creates a heading `X.Y.Z` while the newest tag is still the previous one: the check fails, so the sealing pull request is red and **cannot be merged**. Tagging first inverts it — the tag exists, the sealing PR makes the two agree, and it goes green. *(Verified on `v1.1.0`: the tagged commit still carried `## [1.0.0]` as its newest heading. At `v1.0.0` the mistake was invisible — no tag existed yet, so the guard was a silent no-op.)*
> ⚠️ **Between the tag and the merge of the sealing PR, `main` is red on that one check.** That window is structural, it is expected, and it closes with the sealing.
| 4 | **the maintainer** | ⚠️ **1st release — VERIFY that the ghcr package is pullable, and act ONLY if it is not.** On a **PERSONAL** account, a package published from a **public** repo inherits its access: it is pullable **immediately**, no action needed. On an **ORG**, it can be **PRIVATE** *(org default)* → anonymous `docker pull` = **403**, and **no one can self-host**. **`configure-repo.sh` runs the test itself** and only requests the action if it fails. |
| 5 | Claude | Verify that the image is **actually pullable** — `configure-repo.sh` tests it **anonymously**, the way the prod host does. ⚠️ **A GREEN "Publish image" job PROVES NOTHING**: it can succeed while the image stays **unpullable** (private package). |

> 🔴 **PROMOTING TO PRODUCTION USED TO DESTROY STAGING, as long as the repo is PRIVATE** — fixed at the root, but a repo configured before the fix still carries the old setting. Full mechanism: `repo-controls.md`, "Full flow".
> **→ After a promotion on a PRIVATE repo, RECREATE `develop` immediately:**
> ```bash
> git switch -c develop main && git push -u origin develop
> ```
> *(The script now detects and flags this on its own.)*

> ⚠️ **Immutable releases are NOT retroactive.** They must be set up **before v1** — after that, it is too late for releases already published.
> `configure-repo.sh` handles this **from the private state onward** *(the setting is available there)*: nothing to wait for, and a repo that never flips to public is covered too.

---

## 4 · Flip PRIVATE → PUBLIC

> 🔴 **The most dangerous moment of the lifecycle** *(why: `repo-controls.md`, "The private → public switch")*. Hence step 1, non-negotiable.

| # | Who | Action |
|---|---|---|
| 1 | Claude | **`gitleaks` on ALL refs**, not just `main` — a secret in an old pushed branch becomes public too. |
| 2 | Claude | Verify that **no `<placeholder>` remains** in the versioned files — especially `<contact>` in `SECURITY.md`. |
| 2b | Claude | **Only on an ADOPTED repository** — a project generated here already commits `CLAUDE.md`, reduced to the `@AGENTS.md` import, from its first commit *(standard §6)*. An adopted one carries whatever its author wrote: **read it before tracking it** — machine paths, private repository names, personal preferences all have to leave first, and the history keeps whatever is pushed. Gitignored, it reaches nobody who clones, and **it is the only thing that loads `AGENTS.md`**. |
| 3 | **the maintainer** | Flip the visibility *(UI)*. |
| 4 | **the maintainer** | **Re-run `configure-repo.sh`** *(ephemeral admin PAT)* → rulesets `main`/`develop`/`tags`, secret scanning + push protection, **private vulnerability reporting**, **immutable releases**, Pages, description, topics, and **THE ACTIVATION OF CODEQL** *(default setup — it waits for the 1st analysis, then sets the `code_scanning` rule)*. **The script is idempotent: that is what it is built for.** |
| 5 | **the maintainer** | **ORG repo only** — Settings → **Moderation options** → **Reported content** → "Prior contributors and collaborators". **No API.** Without this click, community health **caps at 87%**. ⚠️ **This item exists ONLY on an ORG repo** *([GitHub changelog, 2020](https://github.blog/changelog/2020-06-23-community-content-reports-included-in-community-profile/))*: an org repo's checklist counts **8 items**, a personal account's **7**. **A personal repo at 100 % and an org repo at 87 % can hold EXACTLY the same files** — comparing the two scores means nothing. |
| 6 | — | **Nothing to do for the workflows**: `pages.yml` carries `if: visibility != 'private'` — it is `skipped` in private and **wakes up on its own**. ⚠️ **CodeQL is NO LONGER a workflow** *(there is no more `codeql.yml`)*: it is activated **by the script**, at **step 4**, in ***default setup*** — GitHub detects the languages there and **keeps them up to date on its own** *(`repo-controls.md`)*. |
| 7 | — | **Nothing to do for the `code_scanning` rule**: at **step 4**, the script **activates CodeQL, WAITS for its 1st analysis, THEN sets the rule** — in a **single** run *(otherwise `main` would stay UNGUARDED until a re-run — consequence detailed in §1 step 7a)*. |
| 8 | Claude | Verify by reading: community health **100%** · CodeQL **green** · rulesets **active** · secret scanning **on**. |

> **CodeQL analyzes the entire history at once** at the flip — `semgrep` + `osv-scanner` therefore run **from day one** *(detail: `repo-controls.md`)*.

---

## 5 · Evolving a live project

**The archetype does not change — a capability is ACQUIRED.** *(`repo-controls.md`, detailed checklists)*
🔴 **"Capability" is a CLOSED list of three: Pages · published image · staging host.** Adding a tool — a task tracker, a linter, a library — is **not** one, follows none of this section, and starts by checking what already exists *(`METHODE.md`)*.

| Need | Capability | ⚠️ The trap |
|---|---|---|
| "others should be able to **self-host**" | `--artefact` | **THE ORDER.** The workflow must reach `main` **BEFORE** `configure-repo.sh` requires `build-check` — otherwise **the repo locks itself out**, including against the PR that brings the workflow. |
| "a **host** appears, it needs validating" | `--staging` | Re-run `configure-repo.sh`: it sets the `develop` ruleset **and allows the merge commit** *(squash-only is incompatible with a staging branch)*. |
| "the site moves **off Pages**" | remove `--pages` | Delete `pages.yml`. **Never** leave it running "just in case" — an orphaned workflow is a check that no one reads anymore. |
| **removing** a capability | — | ⚠️ Remove `build-check` from the **required** checks **BEFORE** deleting `docker-publish.yml`. Otherwise the check stays required while nothing produces it anymore → **every PR blocked forever**. |
| bringing an **EXISTING** repo into compliance | — | ⚠️ Its CI names its jobs however it likes, while the ruleset requires **`checks`** *(and `build-check` with `--artefact`)*. **`configure-repo.sh` now REFUSES to set the ruleset** if no job carries the name — a `--dry-run` says so without writing. The fix: an aggregator job named `checks`, `needs:` every other job, `if: always()` *(model: this repo's own `ci.yml`)*. |
| an existing repo has **NO secret scan at all** | — | **`templates/workflows/gitleaks.yml`** is a standalone workflow for exactly that case: pinned version, checksum-verified, full history, plus a weekly run that catches a secret pushed with `--no-verify`. **Copy it by hand** — no script places it, because a repo generated here already runs gitleaks inside its `ci.yml`, and two identical scans buy nothing. |

### Bringing a project back in line with a newer template — **assisted regeneration**

The project carries the version it was born from *(the stamp in its `AGENTS.md`)*. Bringing it forward is **regenerate, then compare** — never a patch applied blind. Measured on 2026-08-07, and the reason is not a preference: **a generated project is not a subset of the template**. The generator filters *(it copied 3 of 12 checks at `v1.2.0`)*, renames *(`templates/repo/X` lands as `X`)* and **substitutes** *(year, holder, slug, version, image name)* — so a `git diff` of the template applies to **56 of the 85 files today** — a share that moves with every check added — and leaves the rest silently stale. Half-updated is not half-right: a fresh check reading a stale file turns the project red for a fault it does not have.

| # | Who | Action |
|---|---|---|
| 1 | Claude | **Read the origin stamp** in the project's `AGENTS.md` — it carries the version, the origin, **and the exact options the project was generated with**, every flag explicit. ⚠️ **A project born before those options were stamped carries the version alone**: deduce them from the tree *(`docker-publish.yml` → `--artefact` · `pages.yml` → `--pages` · a `develop` branch → `--staging` · the CI's toolchain → `--type`)*, and **write them into the stamp at step 5**, so the next comparison never has to guess again. |
| 2 | Claude | **Generate a reference project** with those exact options, into a **scratch directory**, from the template at its current version. |
| 3 | Claude | **`diff -ru` the two trees**, excluding `.git/` and `.ci-tools/`. Three piles: what the project never touched *(take the new version)* · what it deliberately changed *(keep, and say so)* · what the template no longer ships *(delete, after checking who uses it)*. |
| 4 | Claude | Apply pile by pile, **then run `./check.sh --house` in the project** — the update is finished when it is green, not when the files are copied. |
| 5 | Claude | **Move the stamp forward** in `AGENTS.md`, in the same branch — version, origin **and options**. A stamp left behind makes the next comparison start from a version the tree no longer holds. |

⚠️ **The reference project is scratch** — it exists to be compared and deleted, never to be pushed.

---

## 6 · Ongoing maintenance

| What | Who | When |
|---|---|---|
| **Renovate PR** *(EVERYTHING: auto-detected ecosystems — actions, npm, docker, pip… — **and** the 4 pinned binaries VERSION+SHA256)* | Claude — **autonomously** | weekly. Minor/patch grouped, **majors alone**. **Routine = PR reviewed by a human; SECURITY = auto-merged** *(no action needed)*. ⚠️ **If a binary's checksum is wrong, `sha256sum -c` fails the CI** — loudly. A red PR gets closed. |
| **Dependabot** and **code scanning** alerts | Claude — **autonomously** *(dismiss/reopen)* | on receipt |
| **SECRET SCANNING alerts** | 🔴 **THE MAINTAINER ALONE** | The assistant is **read-only** on these *(why: §1 step 3)*. |
| **Write PAT rotation** | Claude **alerts at D-14** · **the maintainer regenerates** | every **90 days** |
| **`SUIVI.md`** | Claude — **on its own** | consolidate · purge what's shipped **from HERE — it is synthesized into an archive, never lost** *(`METHODE.md`)* |

---

## 7 · The actions Claude CANNOT perform

*(These are not oversights: this is the security model — `secrets-and-auth.md`.)*

- **Create** or **delete** a repo · **change visibility** → **account**-scoped right.
- **Everything requiring `Administration`**: rulesets, secret scanning, Pages, immutable releases, description, **topics** → **ephemeral admin PAT, run by the maintainer**. ⚠️ **These are actions performed by the SCRIPT, not "by hand" actions**: `configure-repo.sh` sets all of them *(topics included: `PUT /repos/{o}/{r}/topics` requires `administration=write`)*.
- **Making a ghcr package public** → **UI, no API** *(fine-grained PATs do not cover ghcr — only `classic` PATs do)*. The script **TESTS it** *(real anonymous pull)* and **only requests it if the test fails** *(detail: §3 step 4)*.
- **Reported content** → UI, no API.
- **Enabling Dependabot malware alerts** *(npm repos)* → **UI, no API** — npm-only, available from private Free onward *(detail: §1 step 9)*.
- **2FA** → **UI, no API.** ✅ **ALREADY ACTIVE on the maintainer's account.** **ACCOUNT**-level setting, **once and for all** — **not** a per-repo action. ⚠️ **Not to be confused with an ORG's MANDATORY 2FA**, which is a **distinct** setting *(enforcing 2FA on members)* — see the box below.
- **Dismissing a secret scanning alert** → **the maintainer alone.**

> ### If the repo lives in an ORGANIZATION — 4 settings, once per org
> **None can be scripted without an `Organization Administration` PAT** *(a permission with no granularity: whoever can read can write everything)* — so **UI, an action by the maintainer**.
> ✅ **Already set on the account's orgs** *(25/07)* — this is the **expected state** of every org:
>
> | Setting | Where | Value |
> |---|---|---|
> | **Mandatory 2FA** | `/settings/security` | enabled |
> | **Classic PATs** | `/settings/personal-access-tokens?tab=classic` | **Restrict** *(blocked)* |
> | **Fine-grained PATs** | `/settings/personal-access-tokens` | admin approval **required** + max lifetime **90 days** |
> | **Default package visibility** | `/settings/packages` | ⚠️ on an **org**, a ghcr package is **private by default** *(§3 step 4)* |
>
> ⛔ **What the org does NOT bring, despite appearances**: **org rulesets** require **Team** *(explicit banner on `/settings/rules`)* · a **code security configuration** only replaces the repo action from **several** repos onward *(below that, `configure-repo.sh` already does everything)* · the **"Advanced Security"** screen suggests **Dependabot** is behind the paywall: **that is false**, it is free, private included — it is `/settings/security_analysis` that tells the truth.

> **Why the admin PAT is DISPOSABLE rather than downgraded afterward** → `secrets-and-auth.md`. *(In a word: **revoking is binary; downgrading rights is not** — and a manual removal is forgettable.)*
