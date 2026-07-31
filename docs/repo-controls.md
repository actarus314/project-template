# Repo controls — from commit to production

> Reference. Complements `claude-code-project-standard.md` §18.
> **The "Private" column is the key**: a private repo on the Free plan has **no ruleset**.
> The controls run, but **nothing requires them** — a red PR can be merged.

## The flow — where the code goes

**The single principle: `main` is production.**
We **never** write to it directly — the only way in is a **pull request with green CI**.
Everything else follows from that.

> ### What decides the flow: *a single question*
> **"Is there a host to VALIDATE before production?"** — that's the **`staging`** capability, and only that one.
> **Not the language, not Docker.**
> A `node` project with no host to validate does **not** need `develop`. A Pages site packaged as an image **doesn't either** — the image *is* the page.
> Publishing an **artefact** (tag → ghcr image) is an **independent** capability: it attaches to **both** flows below.

### Without `staging` — GitHub Flow, two branches are enough

This is the case of a Pages site, **and also** that of a static site packaged as an image so third parties can self-host it.
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
| 4 | Merge **only if the CI is green** | `gh run list --commit "$(gh pr view <n> --json headRefOid --jq .headRefOid)"` then `gh pr merge --squash` *(**not** `gh pr checks`: the `Checks` permission cannot be granted — standard §18)* |

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
> *(standard §12.)*

> ### Where we do NOT tighten the screws — *too many controls kills the control*
> - **No lint at pre-commit** — no linter is universal across the three toolchains; enforcing one would fail the hook on the very first commit.
> - **Only one blocking control locally: secrets.** Vital, instant, and **irreversible once pushed** — the three criteria that justify blocking. Everything else waits for the CI, where waiting costs nothing.
> - **Zero mandatory review** (`required_approving_review_count = 0`): solo, self-approving would be theater.

---

## The controls — what verifies the code

### Development machine

| Where / when | What | With what | How | Private |
|---|---|---|---|---|
| Commit | No secret in the staged files | `gitleaks` | hook `.githooks/pre-commit` | ✅ |
| Push | No direct push to `main`/`develop` | hook `pre-push` | hook `.githooks/pre-push` — *the substitute for the missing ruleset* | ✅ |

### Continuous integration — job `checks` (`ci.yml`)

| Where / when | What | With what | How | Private |
|---|---|---|---|---|
| Pull request | Secrets across the **full** history | `gitleaks` | pinned binary + checksum | ✅ |
| Pull request | **Application code** flaws | `semgrep` | `p/security-audit`, `p/owasp-top-ten`, `--exclude=.github` | ✅ |
| Pull request | Vulnerable dependencies (all manifests, `-r .`) | `osv-scanner` | pinned binary + checksum | ✅ |
| Pull request | Workflows: syntax + shell | `actionlint` | pinned binary + checksum | ✅ |
| Pull request | Workflows: `${{ }}` injection, pinning | `zizmor` | config `.github/zizmor.yml` | ✅ |
| Pull request | Tests · types · npm audit | `npm test` · `npm run typecheck` · `npm audit` | `node` toolchain | ✅ |
| Pull request | Syntax of all JS | `node --check` | `static` toolchain | ✅ |
| Pull request | Incoming dependency + **licenses** | `dependency-review` | gated on public (requires GHAS) | ❌ |

### Continuous integration — other jobs

| Where / when | What | With what | How | Private |
|---|---|---|---|---|
| Pull request | Docker image CVEs (CRITICAL/HIGH) | `trivy` | job `build-check` — **required check** | ✅ |
| PR + push | **Cross-file** static analysis | `CodeQL` | **default setup** (enabled by `configure-repo.sh`) — public only | ❌ |
| Repo **without CI** | Secrets (full history) | `gitleaks` | standalone `gitleaks.yml` — PR + weekly | ✅ |

### Server — set up by `configure-repo.sh`

| Where / when | What | With what | How | Private |
|---|---|---|---|---|
| Merge | PR mandatory · **required** checks · no force-push | `main` / `develop` rulesets | unavailable in private (Free) | ❌ |
| Tag | `v*` tag can't be moved or deleted | `tags` ruleset | without it, the prod pin means nothing | ❌ |
| Release | Assets can't be replaced | immutable releases | `PUT /immutable-releases` — **not retroactive** | ❌ |
| Server push | Secret in the push | secret scanning + push protection | native GitHub | ❌ |
| After release | **Is the image pullable?** | `curl ghcr.io/v2/…/manifests` | **anonymous** test, like the prod host | ❌ |

### Publication & monitoring

| Where / when | What | With what | How | Private |
|---|---|---|---|---|
| Push tag `v*` | Image published to ghcr | `docker-publish.yml` › `build-push` | triggered by the tag | ✅ |
| Weekly | Updates for all dependencies (npm · docker · actions · pip…) | Renovate | `renovate.json` — auto-detected, minor/patch grouped | ✅ |
| Weekly | CVEs of the **PUBLISHED** image (CRITICAL/HIGH) | `trivy` | `docker-publish.yml` › `scheduled-scan` — same flags as `build-check` | ✅ |
| Continuous | Dependency CVEs (**detection**) | Dependabot alerts | native — free even in private; Renovate **reads** these alerts and opens the fix PR (**remediation**) | ✅ |

---

## The private → public switch

The nominal cycle: the repo **is born private**, it **becomes public**.
Everything that was dormant activates **all at once** — it's the most dangerous moment of its life.

| While private — *everything runs, nothing is required* | On going public — *the server enforces what discipline used to hold* |
|---|---|
| ✅ gitleaks (hook + CI, full history) | ✅ `main`, `develop`, `tags` rulesets |
| ✅ `pre-push` hook: no direct write to `main` | ✅ **Required** checks before merge |
| ✅ semgrep · osv-scanner | ✅ Secret scanning + push protection |
| ✅ actionlint · zizmor · trivy | ✅ CodeQL — *scans the whole history at once* |
| ✅ tests · typecheck · Renovate + Dependabot alerts | ✅ dependency-review · immutable releases |
| ❌ **No ruleset** — a red PR can be merged | ✅ Private vulnerability reporting |


## The hole in the private phase

In private, GitHub requires **nothing**: a direct push to `main` is accepted, a red PR is mergeable. Discipline is therefore **tooled** (hooks `pre-commit` / `pre-push`, bypassable with `--no-verify` — a decision, not an accident). **Only one point stays human**: never merge a red PR — check via `gh run list --commit <PR-head-sha>`, **never** `gh pr checks` (the `Checks` permission cannot be granted in fine-grained).

**Full detail** (CodeQL license in private, the permanent role of Semgrep/osv-scanner, the definition of green, the false-green trap, exact command): **standard §18, "The hole in the private phase"**.
