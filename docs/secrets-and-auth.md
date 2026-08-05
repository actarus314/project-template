# Secrets and authentication — accessing without leaking

> Reference. This document **owns** one subject: secrets and GitHub authentication *(standard §4, §5, and the PAT matrix that used to live in a separate config file)*.
> It answers one question: **how does a machine authenticate against GitHub without a secret ever reaching a versioned file.**

---

## Secrets management

**Strict rule**: no secret in a versioned file. Ever.

### The 2 secret locations

| Location | Content | Usage |
|---|---|---|
| `repo/.env` | **App** API keys (`ALCHEMY_API_KEY`, `DUNE_API_KEY`, `TELEGRAM_BOT_TOKEN`, …) — **not the PAT** | Consumed by the app at runtime and by Claude Code in dev |
| `repo/.envrc` | The repo's **`GITHUB_PAT`** (dev secret) + loads `.env` + `export GH_TOKEN=$GITHUB_PAT` | direnv: exposes the PAT to git/gh, confined to the folder |
| `workspace/secrets.md` | Auth procedures, pointers, human-readable values, expiration dates, where to regenerate | Human reference + pointer for Claude Code |

> **The GitHub secret lives in exactly one place: `repo/.envrc` (`GITHUB_PAT`).** The git remote stays a **bare URL** (never `https://<PAT>@github.com/...`), and `.envrc` re-exports this PAT as `GH_TOKEN` in the folder's shell. No secret in clear text in `.git/config`.

### Why this separation

- `.env` = a technical format consumable by the app and scripts (no explanations, just key=value pairs).
- `workspace/secrets.md` = human format: *where* to find it, *how* to regenerate it, *which* scopes, *when* it expires. Essential for resuming from a NAS backup on a new machine.

### Duplication to avoid

- An API key must exist **in exactly one place**: `.env`. If Claude Code needs it, it reads `.env` directly. NEVER duplicate it into `settings.local.json`.

---

## GitHub authentication

**Principle: separate reading (broad, harmless) from writing (narrow, per repo). No broad RW token anywhere.** Two watertight auth channels: **cloud** (claude.ai) and **local** (CC in terminal/desktop) do not share the same mechanism — changing one does not affect the other.

### Access overview

| Actor | Token / mechanism | Scope | Duration |
|---|---|---|---|
| **The maintainer** | github.com web interface | Everything | — |
| **Chat / Projects (cloud)** | Claude GitHub App, installed by the owner | Read-only on authorized repos (personal + orgs) | revocable |
| **CC — read** | **public-RO** fine-grained PAT (`claude-ro`) in `gh` | All of public GitHub, 5000 req/h, **zero private** | **no expiration — deliberate** (see below) |
| **CC — write** | fine-grained RW PAT, **1 per repo**, in `repo/.envrc` | This repo only | **90 days** + J-14 alert |
| **Container host** | classic RO PAT, read-only — the owner account | All repos (personal + orgs) | 1 year |

### Public reading + default Git auth → `gh` in public-RO

The `gh` CLI carries a **fine-grained "Public repositories (read-only)"** PAT: reads all of public GitHub at 5000 req/h, **zero access to private repos**. It is the default token for every CC session, and it is harmless if leaked.

> ⚠️ **Do NOT use `gh auth login` in web/OAuth flow**: it always forces the `repo` scope (RW on ALL repositories). A PAT with hand-picked rights is installed instead, via `--with-token`.

**Initial setup (once per machine):**
```bash
brew install gh direnv
# Create a fine-grained "Public repositories (read-only)" PAT on github.com
echo "<public-RO-PAT>" | gh auth login --with-token
gh auth setup-git                              # git delegates to "gh auth git-credential"
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc   # direnv hook
```

**Verification:**
```bash
gh auth status
gh api rate_limit --jq .rate     # limit = 5000
```

Reading **private** repos from CC is deliberately not configured locally (a classic `repo` scope would be RW in disguise; a fine-grained PAT only covers one owner at a time). That happens via the **GitHub App on the Chat/Projects side**.
Accepted corollary: from a terminal, Claude **sees neither organizations nor private repos** — they must be named for it.

> ⚠️ **Pitfall — an org CAN reject `claude-ro`, even for public reads.**
> An organization can impose a **maximum lifetime** on fine-grained PATs *(org Settings → Personal access tokens → "Require tokens to expire")*.
> If this limit exists, `claude-ro` — **no expiration** — is rejected with a **403** on **every** repo in the org, **including public ones**:
> *"The '<org>' organization forbids access via a fine-grained personal access tokens if the token's lifetime is greater than 90 days."*
> **Confusing symptom**: the same `gh api` call **succeeds from `repo/`** (direnv exposes the 1-repo, 90-day PAT there) and **fails from elsewhere** (`gh` falls back to `claude-ro`). The token at fault is not the one assumed.
> The pitfall applies to any org that enables this — and the limit can also be lifted afterward, org-side.

> **`claude-ro` is deliberately WITHOUT EXPIRATION.** This is not an oversight.
> A short lifetime only protects against **persistence after the secret is stolen** — and this token is read-only on **public** data: an attacker who steals it only gets what is already public. Forcing rotation on it would be a recurring chore for zero gain.
> *(GitHub's only safeguard here: automatic revocation after 1 year of inactivity.)*
> **The opposite reasoning applies to write PATs** — they touch private code and publish: 90 days, with a J-14 alert.

### Writing (push, PR, issues) → 1-repo fine-grained PAT exposed by direnv

- **One PAT per repo**, created fine-grained, *Only select repositories* → **this repo only** (owner = the repo's account or org).
- **Consistent standard permissions**: `Contents R/W`, `Metadata R`, `Pull requests R/W`, `Issues R/W`, `Workflows R/W`, `Actions R/W`.
  **+ alert permissions**, for autonomous security maintenance: Dependabot & Code scanning `R/W`, Secret scanning `R`.
  **+ `Administration: read`** *(never write)*.
  *(Detailed matrix, derivation of `Administration: read`: "PAT permissions — two tiers", below.)*
  **Everything else: No access** — and **never** `Administration: write`.
- Stored in `repo/.envrc` as `GITHUB_PAT`. **Remote as a bare URL** (never a PAT in the URL).
- Exposed to git/gh **only inside the folder** via direnv. `repo/.envrc` (gitignored) holds the PAT and stays **sourceable in bash** *(no `dotenv` builtin — a safety net if a `source` ever replaces `direnv exec`, cf. "Non-interactive shell", below)*:
  ```
  set -a; [ -f .env ] && . ./.env; set +a   # loads the app vars from .env (bash equivalent of `dotenv`)
  export GITHUB_PAT=<PAT 1-repo>
  export GH_TOKEN="$GITHUB_PAT"
  ```
  then `direnv allow` once. Entering the folder → push/PR via the repo's PAT; leaving it → back to public-RO.
- Documented in `workspace/secrets.md`: expiration date, target repo, regeneration link.

**Usage (direnv loads everything, no `source .env`):**
```bash
git push                                   # auth via the repo's PAT
gh pr create --title "..." --base main
gh issue list && gh run list
```

> **Workflows pitfall:** without the `Workflows: R/W` permission, GitHub **rejects** any push touching `.github/workflows/`, even with `Contents: R/W`. Keeping it in the standard avoids the surprise.

> 🔴 **ACCEPTED limitation of this model — `gh pr checks` and `gh pr view` do not work.**
> Both read `statusCheckRollup`, which requires the **`Checks`** permission. It is **documented** by GitHub but **absent from the UI** for fine-grained PATs: **impossible to grant** *(github/community#129512, cli/cli#12597)*. This is **not** an omission in the matrix above — **there is nothing to add to it**.
> **The exact error, and the command's derivation from the endpoints: `repo-controls.md`, "In private, NOTHING is enforced".**
> **This is not cosmetic**: the only barrier of the private mode (*"never merge a red PR"*, `repo-controls.md`) relied on `gh pr checks`. → It now goes through `gh run list --commit <sha>` (`Actions: read`, already there). **The exact command, and the false-green pitfall: `repo-controls.md`, "The control matrix".**
> *(The GitHub App can be granted `Checks` — but it stays out of scope for the reasons in the table below: the auth model isn't reopened for a CLI command that has a zero-cost substitute.)*

### Expiration: 90 days + automatic alert (never caught by surprise)

**Every new write PAT is bounded to 90 days.** The expiration must **never** be discovered mid-session, with a `git push` in hand.

`repo/.envrc` embeds an **automatic alert**: GitHub returns the end date in the `GitHub-Authentication-Token-Expiration` header, read once a day (cached in `.git/`, never committed). At **J-14**, the terminal prints:

```
  /!\  GITHUB_PAT expire dans 12 jour(s), le 2026-10-11.
      Regenerer (90 j, memes permissions) : https://github.com/settings/personal-access-tokens
      Puis : remplacer le PAT de ce .envrc + la date dans ../workspace/secrets.md
```

Silent when everything is fine, offline, or if the PAT doesn't expire. Distinct message if the PAT is **already** dead.
This is what makes the 90 days painless: the rotation is **announced**, not endured. Without this alert, a short duration is just one more surprise outage.

### One convention for `.envrc` — the old one is banned

| | ✅ Current convention | ❌ Old convention (to migrate) |
|---|---|---|
| Loading `.env` | `set -a; [ -f .env ] && . ./.env; set +a` | `dotenv` (**direnv** builtin) |
| Where the PAT lives | `repo/.envrc` (`GITHUB_PAT`) | `repo/.env` |

Two reasons:
- **Keep `.envrc` sourceable in pure bash.** Push goes through `direnv exec` *(which does handle `dotenv`)*; `.envrc` is kept bash-pure as a **safety net**: if someone falls back on `source ./.envrc`, a `dotenv` there breaks it *(`dotenv: command not found`)*. Pure bash works everywhere.
- **A PAT in `.env` leaks into containers.** A `docker-compose.yaml` with `env_file: .env` injects `GITHUB_PAT` into the container — visible via `docker inspect`. `.env` is reserved for **app** keys; the PAT lives in `.envrc`, and **nowhere else**.

### Mechanisms evaluated then rejected — do not reopen without new facts

The **1-repo** fine-grained PAT is the optimum *(full research: `workspace/archives/conception/RECHERCHE-auth-github.md`)*. Evaluated then **rejected**:

| Mechanism | Reason for rejection (verified) |
|---|---|
| **GitHub App** (installation token) | In a `git push` workflow, it brings **neither a `[bot]` identity nor `Verified` commits**: the token only authenticates the **transport**, the commit author is fixed by `git config`. Those benefits only exist for commits created **via the API**. What's left: a `.pem` key that **never expires** and a third-party dependency. |
| **GitHub App + `ghtkn`** (8h user token) | No silent refresh: device flow **browser prompt ~3×/day**, and the tool **refuses by design** to let an agent trigger it. Incompatible with any autonomy. |
| **Classic PAT** | `repo` scope = **all-or-nothing**: RW on every repo, public **and** private, of every owner. `public_repo` opens no private repo. No scope targets **one** repo only. Maximum blast radius. |
| **1 PAT per owner** (instead of 1 per repo) | Saves a few minutes/year while **multiplying a session's blast radius by N**. 1-PAT-per-repo **is** the scoping. |
| **PAT in the Keychain** | Breaks the "one folder to copy" principle (`claude-code-project-standard.md` §2 · `repo-controls.md`): the secret would no longer travel with the folder to a new machine. |

> **What no auth mechanism solves.**
> Facing a **prompt injection** (cf. GitLost, 2026), the hijacked agent holds a token that is **valid at the moment of the attack** — its lifetime changes nothing about that.
> A short expiration only limits **persistence after the secret is stolen**, not immediate misuse.
> The only mitigation that actually bites is **scope**: public-RO by default, private access escalated **deliberately**, and **never** the combination of a broad credential + a shell + ingestion of untrusted content.

### Non-interactive shell (Claude Code's Bash tool) — direnv NOT loaded

Everything above assumes an **interactive** shell, where the direnv hook has run.
But **Claude Code's Bash tool launches non-interactive shells**: the direnv hook **does not fire**.
Chain of consequences: `GITHUB_PAT`/`GH_TOKEN` are **absent from the env** → `git` falls back to the machine's credential helper (often `osxkeychain`, which carries the **public-RO** PAT) → **403 even on a plain read of a private repo**.
All while the right PAT is **indeed present** in `.envrc` — hence a thoroughly confusing symptom.

> **Symptom**: `git fetch/pull/push origin` → `403` / `Write access to repository not granted`, while `repo/.envrc` holds the correct `GITHUB_PAT`.

**The wrong reflex to ban**: putting the PAT in the URL (`https://x-access-token:$TOKEN@github.com/...`) — that exposes it (ps, history, reflog, `.git/config`). **The URL stays bare, always.**

**Clean procedure (verified)** — a **local** credential helper that reads `$GITHUB_PAT` from the env, configured once (persists in `repo/.git/config`, **no secret stored**, just the variable name; the initial `""` resets the list to run ahead of osxkeychain):
```bash
git config --local credential."https://github.com".helper ""
git config --local --add credential."https://github.com".helper \
  '!f() { echo username=x-access-token; echo "password=${GITHUB_PAT}"; }; f'
```
Then **prefix every `git`/`gh` call with `direnv exec`**: direnv evaluates `.envrc` *(the `allow` safety net respected)* and launches the command with `GITHUB_PAT`/`GH_TOKEN` in its env — the helper reads `GITHUB_PAT`.
```bash
direnv exec . git push origin <ref>       # from repo/ — BARE URL, token via the helper
direnv exec . gh pr create / gh pr merge   # gh via GH_TOKEN
```
> ⚠️ `direnv exec` **does not change the CWD**: outside `repo/`, targeting the repo requires `direnv exec <repo> git -C <repo> …`.
> Without `direnv allow`, `direnv exec` **refuses** `.envrc` *("…is blocked. Run `direnv allow`")* and launches nothing — no more confusing 403.
> Equivalent alternative if `gh auth setup-git` is configured **globally** on the machine: a plain `export GH_TOKEN="$GITHUB_PAT"` suffices (git delegates to `gh auth git-credential`, which returns `GH_TOKEN`). The local helper above is more robust because it doesn't depend on the machine's global state.

---

## PAT permissions — two tiers

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

The recurring PAT is exactly the **uniform permissions** listed under "Writing (push, PR, issues)" above, **+** the 3 alert permissions, **+ `Administration: read`**. **`Administration: write`: never.**

**Verified**: handling (dismiss/reopen) a Dependabot or code scanning alert **only** requires the dedicated permission in *write* — **no Administration**. Opening a PR = Contents + Pull requests write ; merging = Contents write.

### `Administration: read` — why one more permission, and why that one

**It mutates nothing.** What makes `Administration` formidable *(deleting the repo, flipping visibility, rewriting a ruleset)* is in the **write**, reserved for the ephemeral admin PAT.

It closes a **verification** gap, derived from three endpoints that no other permission opens:

| Read | Otherwise |
|---|---|
| `GET /automated-security-fixes` · `GET /vulnerability-alerts` | the state of the security toggles is **not readable**: the only check is a screenshot from the maintainer |
| `GET /branches/{b}/protection` *(+ `/required_status_checks`)* | **CLASSIC** protection stays invisible — the `rulesets` API doesn't show it, and it can lock `main` **forever** |

🔴 **The underlying reason: a `✓` printed by a script is not an applied setting.** A `--dry-run` once announced 3 settings, of which **2 were impossible**, and classic protection once blocked every PR on a repo, CI green. Without reading, these two failures are **structurally undetectable** by the assistant — leaving autonomous security maintenance to fall back on the maintainer.

> 🔴 **`Checks` is NOT in this list — and CANNOT be.** The full account of that limitation, its citations and the substitute command are under "Writing (push, PR, issues)" above.

### One-shot admin — EPHEMERAL token, no dormant token

The Administration PAT lives **nowhere**: not in the keychain, not in `.envrc`, not in shell history.
**Created → used → revoked**, within minutes. `configure-repo.sh` asks for it as **masked input**.

- Fine-grained · **"Only select repositories" = THIS repo** → blast radius **1 repo**. **Complete** recipe, one permission per endpoint called *(verified against the REST doc "Permissions required for fine-grained PATs" — derived from the endpoints, **NEVER** discovered by trial and error)*:

  | Permission | Level | Why |
  |---|---|---|
  | **Administration** | **write** | `PATCH /repos` (merge, description, homepage) · `PUT /vulnerability-alerts` · `*/rulesets` · `PUT /immutable-releases` *(same permission — nothing to add to the recipe)* |
  | **Pages** | **write** | `POST`/`PUT /pages` — site creation, source = workflow |
  | **Code scanning alerts** | **read** | `GET /code-scanning/analyses` — knowing whether CodeQL has run |
  | **Actions** | **read** | 🔴 `GET /actions/runs/{id}` — **track the run of the 1st CodeQL analysis**. Without it, the script doesn't know when it finishes → it **doesn't set the `code_scanning` rule**, and **`main` stays UNGUARDED**. |
  | **Contents** | **read** | `GET /contents/…` — detecting `pages.yml` (private repo) |
  | **Issues** | **read** | `GET /repos/{o}/{r}/issues` — dating Renovate's *Dependency Dashboard* (proof of life before removing the Dependabot safety net) |
  | **Metadata** | read | implicit |

  ⚠ **`Administration` IS NOT ENOUGH**, and **every missing permission fails SILENTLY**: everything else passes, and the missing control doesn't show.
  ⚠ The `enablement: true` of `actions/configure-pages` **does not compensate for** the absence of `Pages: write`: a workflow's `GITHUB_TOKEN` doesn't have that right → Pages site creation fails on **every** deployment.
- Sufficient: **all** of the script's calls are **repo-level** (`PATCH /repos/{o}/{r}`, `PUT …/vulnerability-alerts`, `POST …/rulesets`). No account-level right is required.
- **Repo creation**, though, requires an account-scoped right: it is therefore done **in the UI** (30 s, a few times a year) — which simply removes the need for a broad token.

**Why not a single PAT that has `Administration` removed afterwards**: that would give the assistant, for the duration of the config, the right to **change visibility** or **delete the repo** — and removing the permission would be **manual, so forgettable**, leaving a token alive for 90 days. Revoking a disposable token is **binary**; downgrading its rights is not.

**The assistant NEVER has `Administration: write`.** `configure-repo.sh` is run by the maintainer.
