# GitHub repo configuration — reference

> **One-shot** complement to the standard (`claude-code-project-standard.md` ; auth = `secrets-and-auth.md`).
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
> 🔴 **`develop` follows from STAGING, never from Docker or the language.** A `node` project with no host to validate **does not** have one. Nor does a static site that publishes an image. *(`repo-controls.md`.)*

## 1. Security & code controls — what to enable, where

→ **[`repo-controls.md`](repo-controls.md)** — the baseline every repo gets, plus what each toolchain and each capability adds.

---

## 2. PAT permissions — two tiers

→ **[`secrets-and-auth.md`](secrets-and-auth.md)** — the two tiers *(recurring assistant PAT / one-shot admin)*, the derivation of each permission from the endpoint it opens, `Administration: read`, and why the admin token is EPHEMERAL.

---

## 3. OpenSSF Scorecard — keep / drop (solo, public, small)

→ **[`repo-controls.md`](repo-controls.md)**.

---

## 4. Setup — scriptable vs UI (for `configure-repo.sh`)

→ **[`repo-controls.md`](repo-controls.md)** — what visibility decides, and the endpoint behind each setting.

---

## 5. New repo checklist (created private → flipped public)

0. **Choose the toolchain and the capabilities** — *the three questions, in this order*:
   **(a)** is the site served by **Pages**? → `--pages` · **(b)** does the repo **publish an image that someone ELSE deploys**? → `--artefact` · **(c)** is there a **host to VALIDATE** before prod? → `--staging`.
   Then: `./init-project.sh <project> <owner/repo> [--type static|node|generic] [--pages] [--artefact] [--staging]`.
   *Shortcuts: `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging` · `--type generic` ≡ no capability (any other toolchain — security controls only, build/test to be filled in).*
1. Create the repo — **PRIVATE** (the nominal case), remote as a **bare URL**, 1-repo PAT in `.envrc` (`secrets-and-auth.md`) — with the **3 alert permissions** listed there.
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
