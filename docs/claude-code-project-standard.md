# Organization Standard — Claude Code Projects

> Personal reference. Applies to every new project built with Claude Code (via Claude Desktop or CLI).
> Goal: simple, replicable organization, backupable as a single folder, with a clean separation between what goes on GitHub and what stays private.

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
> All **versioned content (pushed to GitHub)** is written in **English** — code, **code comments**, `repo/` docs, `README.md`, `.env.example`. **Exception**: the project's `README.md` is in English (default) **and** French. Local/gitignored files (`workspace/`, `secrets.md`, `CLAUDE.md`) can stay in French.
>
> **Remaining exceptions**: the local file templates stay in French — `templates/repo/CLAUDE.md`, `templates/repo/.envrc`, `templates/workspace/*`.
> They are gitignored in the generated project and never reach GitHub.
>
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
│   ├── CLAUDE.md                         ← IGNORED — Claude Code instructions (pointers, conventions)
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
| **Remote** | ✅ GitHub *(private or public)* | ❌ **none — never pushed** |
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
| `CLAUDE.md` | No | Yes (Claude Code) | `repo/CLAUDE.md` ignored |
| `node_modules/` | No | Yes (Node runtime) | `repo/node_modules/` ignored |
| `data/` (SQLite) | No | Yes (app runtime) | `repo/data/` ignored |
| Phase 2 plan | No | No | `workspace/plans/` |
| Architecture diagram | No | No | `workspace/docs/` |
| Thinking notes | No | No | `workspace/notes/` |
| GitHub PAT, auth procedures | No | No | `workspace/secrets.md` |

---

## 4. Secrets management

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

## 5. GitHub authentication

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
  *(Detailed matrix, derivation of `Administration: read`: `github-repo-config.md` §2.)*
  **Everything else: No access** — and **never** `Administration: write`.
- Stored in `repo/.envrc` as `GITHUB_PAT`. **Remote as a bare URL** (never a PAT in the URL).
- Exposed to git/gh **only inside the folder** via direnv. `repo/.envrc` (gitignored) holds the PAT and stays **sourceable in bash** *(no `dotenv` builtin — a safety net if a `source` ever replaces `direnv exec`, cf. §5)*:
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
> **This is not cosmetic**: the only barrier of the private mode (*"never merge a red PR"*, §18) relied on `gh pr checks`. → It now goes through `gh run list --commit <sha>` (`Actions: read`, already there). **The exact command, and the false-green pitfall: §18.**
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
| **PAT in the Keychain** | Breaks the "one folder to copy" principle (§2/§18): the secret would no longer travel with the folder to a new machine. |

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

## 6. `CLAUDE.md` — local instructions for Claude Code

File present at `repo/CLAUDE.md` but **ignored by Git**. Claude Code reads it automatically every session (it's in the cwd).

**Typical content**:
- Short project description (one line).
- Useful commands (`docker compose up`, `npm run dev`, etc.).
- Pointers into `workspace/`: where plans, docs, secrets live.
- Project-specific code conventions.
- What must absolutely not be touched (submodules, third-party code, etc.).

**What `CLAUDE.md` NEVER contains**:
- No secret, token, API key (even though it's ignored, zero-secret discipline applies to any file *named by convention* → if `.gitignore` is ever misconfigured, nothing leaks).
- No volatile value that changes every week.

A future cloner who doesn't have `workspace/` (because they only got the repo from GitHub) will work without `CLAUDE.md`, and that's intentional: the repo stays 100% impersonal.

---

## 7. `.claude/` — project-level Claude Code config

Folder entirely **ignored by Git**. Contains:

- `settings.local.json`: permissions granted for this project, Claude-Code-specific env variables, local hooks.
- Possibly `commands/`, `agents/`, `skills/` if project-specific tools are created for Claude Code.

**Files Claude Code reads in `.claude/`**:
`settings.json`, `settings.local.json`, `commands/`, `agents/`, `skills/`, `rules/`.

**Files NOT to create in `.claude/`**:
- `launch.json` (VS Code format, ignored by Claude Code, a classic confusion).
- Any other file not on the list above.

---

## 8. Claude Code's persistent memory

Stored by Claude Code under `~/.claude/projects/<path-hash>/memory/`, where `<path-hash>` is derived from the project's absolute path (e.g. `-Users-<user>-Documents-Claude-<project>`).

**Consequence**: renaming the project folder makes Claude Code create a **new** memory folder and lose the link to the old one.

**Rename procedure**:
1. Rename the project folder (`~/Documents/Claude/old` → `~/Documents/Claude/new`).
2. Merge the old memory folder's content into the new one:
   ```bash
   rsync -av ~/.claude/projects/-Users-<user>-Documents-Claude-old/ \
             ~/.claude/projects/-Users-<user>-Documents-Claude-new/
   rm -rf ~/.claude/projects/-Users-<user>-Documents-Claude-old/
   ```
3. Verify that `/resume` does offer the past conversations.

---

## 9. Typical `.gitignore`

```gitignore
# secrets & local config
.env
.env.local
.envrc
.claude/
CLAUDE.md

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

**Keeping this file alive**: if an entry matches no file in the project (e.g. `dist/`, generated only inside Docker, never on the Mac), leaving it in is not harmful — it's defensive. On the other hand, once a new type of personal file has been added, add it to `.gitignore` immediately.

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

**A Claude Code skill drives it** *(`new-project`)*: it stops at every action the maintainer must perform, gives the exact URL and values, waits for confirmation, then verifies. See `workspace/archives/conception/SKILLS.md`.

## 11. Classic pitfalls to avoid

- **Duplicating an API key** into `.env` and `settings.local.json` → ambiguous source of truth. Always a single copy, in `.env`.
- **Putting a secret in `CLAUDE.md`** even though it's ignored → zero-secret discipline applies to any file *named by convention*. One day `.gitignore` gets misconfigured, and the secret leaks.
- **Creating `launch.json` in `.claude/`** thinking Claude Code reads it → it doesn't. For VS Code debugging, it's `.vscode/launch.json`.
- **Putting thinking docs in `repo/docs/`** → they end up on GitHub even though they're personal. `repo/docs/` is for technical docs meant for a cloner; thinking notes go in `workspace/docs/`.
- **Renaming the folder without merging Claude Code's memory** → loss of `/resume` history.
- **Doing `gh auth login` in web/OAuth flow** → it reinstates the `repo` scope (RW on ALL repositories), exactly what's being avoided. Always `gh auth login --with-token` with the public-RO PAT.
- **Putting the PAT in the remote's URL** (`https://<PAT>@github.com/...`) → secret in clear text in `.git/config`. Remote as a bare URL, PAT exposed by direnv only.
- **Forgetting `direnv allow`** → `direnv exec` **refuses** `.envrc` *("…is blocked. Run `direnv allow`")* and launches nothing — self-diagnosing. *(Interactively: the hook doesn't load → `git push` falls back to public-RO.)*
- **Believing direnv loads the PAT inside Claude Code's Bash tool.**
  It launches **non-interactive** shells: the direnv hook doesn't run → `git`/`gh` return **403, even for reads**.
  Fix: local credential helper reading `$GITHUB_PAT`, + **prefix git/gh with `direnv exec`** (§5, "Non-interactive shell").
  ⚠️ **Never** work around it by putting the PAT in the remote's URL — that's a clear-text leak into `.git/config`.
- **Using `dotenv` (direnv builtin) in `.envrc`** → it is no longer **sourceable in bash**: the `source ./.envrc` fallback then breaks with `dotenv: command not found`. Keep `.envrc` bash-pure; load `.env` via `set -a; [ -f .env ] && . ./.env; set +a`.
- **Putting the PAT in `.env` instead of `.envrc`** → a `docker-compose.yaml` with `env_file: .env` **injects the GitHub PAT into the container** (visible via `docker inspect`). `.env` = **app** keys only; the PAT lives in `.envrc`, nowhere else.
- **Letting a PAT expire without seeing it coming** → surprise outage mid `git push`. The `.envrc` J-14 alert (§5) flags it in advance: don't strip it out when copying the file.
- **Running two Claude Code sessions (or two people) against the same `repo/`.**
  They share `HEAD`, the index, and the files on disk — so they collide.
  A `checkout -b` **switches the other one's branch** without warning · simultaneous edits overwrite each other silently · `gh pr merge --delete-branch` fails (*"main already checked out"*).
  Fix: **one isolated working tree per session** — `git worktree` or a separate clone (§12, "Concurrent work").
- **Creating an owner-scoped PAT instead of 1-repo** → a leak exposes every repo the owner has. Always *Only select repositories* = this repo.
- **Letting `.gitignore` grow with stale entries** → not harmful, but muddies the reading. Clean it up periodically.
- **Setting a calendar reminder for PATs** → pointless now: the `.envrc` **J-14** alert (§5) handles it. Write PATs are **90 days**; `claude-ro` (public read) does **not** expire, deliberately.

---

## 12. Branching policy — **it depends on ONE capability, not on the archetype**

> Branching policy depends on **three independent capabilities**, not on a fixed archetype: reducing the choice to `static`/`node` collapses three distinct questions into one and breaks as soon as the standard case is left behind *(cf. DORA · Fowler · ThoughtWorks Radar)*.

### The 3 CAPABILITIES — independent, composable

`--type` now only decides the **TOOLCHAIN** (which `ci.yml`: `static` = no npm · `node` = npm/tests/types). Everything else follows from **three questions that have nothing to do with each other**:

| Capability | The question to ask | What it triggers |
|---|---|---|
| **`--pages`** | Is the site served by **GitHub Pages**? | `pages.yml` |
| **`--artefact`** | Does the repo **publish an image that someone ELSE deploys**? *(self-hosters, NUCs…)* | `docker-publish.yml` (**`build-check` + Trivy**) · **tag ruleset** · **immutable releases** · **PUBLIC ghcr package** *(the base image is bumped by Renovate, auto-detected — nothing to declare)* |
| **`--staging`** | Is there a **host to VALIDATE** before prod? | **`develop`** branch · `develop` ruleset · merge commit onto `main` · **3-stage flow** |

> 🔴 **`develop` does NOT follow from Docker — it follows from STAGING.**
> A **node** project **with no host to validate** does **not** need `develop`. Neither does **a static site also packaged as an image**: there is no intermediate stage, the image *is* the page served by nginx.

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

⚠️ **`init-project.sh` REFUSES `--staging` on a Pages site without an artefact**: Pages *is* prod, there is **nothing to validate** — the branch would be an empty ritual that drifts until the merge stops happening at all.

**The triple filter catches this kind of regression before it reaches prod** (cf. "Why 3 stages" below) — but only where a host to validate exists. Elsewhere, it would have filtered nothing.

**Git Flow is dead**: `nvie/gitflow` was **archived by its author on 2025-10-14**. Do not bring it back.

### Why `develop` is NOT the anti-pattern it gets accused of being — the nuance is structural

*Environment branches* (one branch per environment) are a documented anti-pattern: Fowler ("*soon leads to a world of misery*"), ThoughtWorks (*environmental drift*). **But the criterion isn't the branch's name — it's what drives the deployment.**

> ✅ **This standard is on the right side**: prod never follows a branch, it follows a **pinned tag** (`APP_IMAGE_TAG=X.Y.Z`, §13). An **artefact** is promoted, not a branch — exactly the alternative DORA and ThoughtWorks recommend *instead of* environment branches.
>
> ❌ **The switch happens** the day `develop` grows long-lived (code diverges by environment) or a host does `git checkout develop` as its deployment's source of truth.
>
> **Rule that follows**: **`develop` stays short-lived** — merged in **days**, not weeks. That's the only condition to uphold.

### Branches

- **`main`**: prod. Protected (ruleset). With the **`artefact`** capability, prod runs on a **pinned tag**, never on the branch.
- **`develop`** *(**`staging`** capability only — **NOT** "node", **NOT** "Docker")*: staging. Protected. **Short-lived.**
- **`feat/<topic>`**: from `develop` **if `staging`**, otherwise from `main`. Deleted on merge (auto).
- **`v*` tags**: **immutable** — a ruleset forbids their deletion and their being moved. Without that, the version pin from §13 guarantees nothing (cf. §17).
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
> `delete-branch-on-merge` deletes the **source** branch of **any** merged PR — so **`develop`**, when the `develop → main` PR merges. **In public**, the `develop` ruleset (`deletion` rule) refuses this; **in private, no ruleset exists** *(§18)* and the branch disappears **silently**.
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

---

## 13. Version pin in production

> ⚠️ **The ghcr package CAN be private — even on a public repo. This gets VERIFIED, never assumed.**
> **PERSONAL account**: a package published from a **public** repo inherits its access → **pullable right away**, no action needed.
> **ORGANIZATION**: it can be **PRIVATE** *(org default)* → the host's `docker compose pull` gets **403**, and the pin below is useless: **there is nothing to pull**.
> → **`configure-repo.sh` queries the registry ANONYMOUSLY**, exactly like the prod host would, and only asks for the manual step **if the pull fails** *(exact UI path: `github-repo-config.md` §2)*. *A green "Publish image" job proves NOTHING.*

On production hosts (NUC, deployed servers), **pin the image tag** in the host's `.env`:

```
APP_IMAGE_TAG=1.1.0
```

Never `:latest` in prod. The point: a deployment must require an explicit `git tag`, not have a push to `main` automatically propagate.

On dev hosts (local Mac): `:latest` or no pin at all is fine.

### Why

`:latest` is a mutable tag that follows the `main` branch. Without a pin, a WIP push to main → release workflow → `:latest` updated → prod-side `docker compose pull` can bring in unreviewed code. With a versioned pin, prod is frozen and an upgrade requires a conscious human action (changing the tag).

---

## 14. Docker hardening (deployment security)

> Security practices validated for **any self-hosted Docker service**. Derived from the `docker-compose-security` skill + the Docker cheatsheet (Security section). Complements §12-13 (workflow & version pin).

### Absolute rules

| Rule | Detail |
|---|---|
| `version:` in compose | **Never** — a forbidden line in every `docker-compose.yml` |
| `sudo` | Always prefix docker commands (NUC) |
| Volume convention | `/docker/<service>/` for every bind mount on the host |
| Image naming | Full path from the build onward: `ghcr.io/<owner>/<image>:tag` |
| `--privileged` | **Never**, except for a documented, absolute necessity |
| Internal ports | `127.0.0.1:HOST_PORT:CONTAINER_PORT` unless explicit public exposure |
| Network | A dedicated **bridge network** per service/stack |

### Hardening philosophy

`root:root` is **kept** (Docker default). A non-root UID *shared* across containers buys nothing: lateral movement is still possible. The real gain comes from **compose directives**. Real order of impact:

1. Regular kernel + docker-ce updates → blocks CVE escapes.
2. `cap_drop: [ALL]` + `no-new-privileges` → strong, easy to add.
3. `read_only: true` + `tmpfs` → blocks write payloads.
4. `pids_limit` + `mem_limit` → anti host-resource-exhaustion.
5. Non-root UID **distinct per service** → useful only when a different UID per service matters.

### Hardened compose template

```yaml
services:
  backend:
    image: ghcr.io/<owner>/my-image:${IMAGE_TAG:-latest}
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp                      # only write path in the container, in RAM
    cap_drop: [ALL]               # zero Linux capability
    security_opt:
      - no-new-privileges:true    # blocks escalation via setuid/setgid
    pids_limit: 256               # fork bomb protection
    mem_limit: 512m               # memory exhaustion protection
    volumes:
      - /docker/myapp/data:/app/data    # bind mount: stays writable despite read_only
    env_file: .env
    networks: [myapp]
    # pure backend: NO ports: block (reachable through the internal network only)

  frontend:
    image: ghcr.io/<owner>/my-image-frontend:${IMAGE_TAG:-latest}
    restart: unless-stopped
    ports:
      - "127.0.0.1:${PORT:-3000}:8080"
    read_only: true
    tmpfs:                        # nginx-unprivileged writes to these 3 paths
      - /tmp
      - /var/cache/nginx
      - /var/run
    cap_drop: [ALL]
    cap_add: [CHOWN, SETGID, SETUID]   # bare minimum for nginx-unprivileged (init, then drop)
    security_opt:
      - no-new-privileges:true
    pids_limit: 128
    mem_limit: 128m
    depends_on: [backend]
    networks: [myapp]

networks:
  myapp:
    driver: bridge
```

### Key directives

- **`cap_drop: [ALL]`**: strips every Linux capability (the highest-impact one). `cap_add` at the strict minimum, case by case — nginx-unprivileged: `CHOWN`/`SETGID`/`SETUID` (init then drop to non-root); Caddy Alpine (`setcap +ep` on the binary): `NET_BIND_SERVICE` even on a high port.
- **`read_only: true`**: container FS read-only (blocks a dropped payload). **Mounted volumes stay writable** (SQLite/file case). Complement with `tmpfs` for the image's write paths (backend: `/tmp`; nginx-unprivileged: + `/var/cache/nginx` + `/var/run`). Crash on startup → often a missing `tmpfs` path.
- **`no-new-privileges: true`**: blocks escalation via setuid/setgid binaries in the image.
- **`pids_limit` / `mem_limit`**: anti fork-bomb / anti host-OOM. Indicative: backend 256 pids / 512m, light frontend 128 / 128m.
- **`user:` (if used)**: always **numeric UID:GID** (the image has no host `/etc/passwd`). Images with an embedded process manager (PM2, supervisord): **no `user:`**, manage via `chown` of the volume host-side.

### Special cases

- **Pure backend (no exposed port)**: no `ports:` block at all; reachable only via the internal Docker network by the other containers in the stack.
- **SQLite / file bind mount**: `read_only` does not affect mounted volumes → the volume stays writable. Hardened as `root:root`, root writes to the bind mount → **avoids the §12 pitfall** (distroless `:nonroot` UID 65532 → silent write loss, `SQLITE_READONLY_DIRECTORY`). Keep a **write probe at boot** (loud failure + non-zero exit) as defense-in-depth. Under `read_only`, a SQLite writer sets `PRAGMA temp_store=MEMORY` (+ `SQLITE_TMPDIR=/tmp`).
- **Embedded process manager (PM2/supervisord)**: starts as root and manages its own drop → no `user:`.

### The runtime must NOT carry its package manager

**`npm` is a BUILD tool.** Leaving it in the runtime image ships **its entire dependency tree — and its CVEs — along with it**.
A Trivy scan already found **CRITICAL/HIGH** CVEs (`pacote`, `picomatch`, bundled inside `npm`) on an app with **zero production dependencies**. The vulnerabilities didn't come from the code, but from the **tool that was forgotten and left in**.

```dockerfile
RUN npm ci --omit=dev \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /root/.npm
```
Scan **green** after this one line. *(A second-stage `distroless` image produces the same effect — heavier to maintain for an identical gain here.)*

### Before prod

- **CVE scan**: `trivy image <image-name>:<tag>` before every deployment — **and as a CI gate** (§17), not only by hand: scanning at deployment time is scanning too late.
- **Per-service audit checklist**: `cap_drop:[ALL]` · `read_only:true` · `tmpfs` covering every write · `no-new-privileges:true` · `pids_limit` · `mem_limit` · ports on `127.0.0.1` if internal · dedicated bridge network · no `--privileged` · no `version:`.

---

## 15. README — dual target: dev + showcase

`README.md` serves **two audiences at once**, without choosing:
- **the dev** who clones/forks/contributes — install, run, structure, contribution;
- **the showcase** — an honest page that makes the project appealing, without overselling.

Polished, concise, **zero fluff**. Bilingual **English then French**, separated by `---`.

**Typical structure**:
- **Title** = `Name — subtitle that says what it is` (not just the name).
- **Hook** aimed at the user's real problem, honest (no hollow superlatives).
- **Disclaimer** up top (⚠️ blockquote) if the tool is third-party/unofficial or touches funds.
- **Screenshots** light + dark theme via `<picture>` + `prefers-color-scheme`; the other theme folded into `<details>`.
- **"Why this exists / Pourquoi"** before the *how*.
- Short sections: Quick start, Structure, License.
- **Tone**: factual, quantified, honest about limitations — and never 2nd person (§1).

Model: `templates/repo/README.md`.

## 16. Project lifecycle docs — **a PRINCIPLE, not mandated files**

> 🔴 **This template initializes EVERY project — including ones that will later be run by a third-party management system** (GSD, superpowers, or other).
> **Forcing our tracking files on them would COLLIDE with theirs** (`.planning/` & co.).
> **Two competing tracking systems in one project means zero system actually kept up.**

### The PRINCIPLE — true regardless of which tool carries it

| Role | The rule |
|---|---|
| **A RESUME doc** | **CONCISE.** Read and edited **very often** → it must stay short. It **POINTS** to the detail *(ADRs, plans, notes)*, **it does not absorb it**. It also carries **what's left to do** *(brief — **POINTS** to a plan if it's heavy)*. |
| **What's shipped gets PURGED** | A resume doc that accumulates the shipped is no longer a tracking doc: **it's a journal**. The shipped moves into its history. |

**Goal**: for a human **or** an AI reopening the project 6 months later to find their footing **without reading a wall of text**.

> **Same rule as `repo/docs/` vs `workspace/` in the template itself**: *the doc read often stays short and points elsewhere; the detail lives elsewhere.* A tracking doc no longer re-read is no longer tracking anything.
> **The general rule, and the fact that the tracking tool is a REPLACEABLE default: `METHODE.md`.**

### The IMPLEMENTATION — replaceable

**By default**, `init-project.sh` places in `workspace/docs/` (never pushed) **one single living doc**:
- **`SUIVI.md`** — the cold-resume doc *(state, environments, history, decisions, pitfalls)* **and "what's left to do"** *(brief)*. A heavy undertaking moves into a **plan** (`workspace/plans/`).

**This file is the DEFAULT, not a dogma.**
→ **`init-project.sh --no-lifecycle-docs`** omits it, **when another system takes over**.

> ⚠️ **BEFORE creating anything to drive a project** — tracking, backlog, planning, context resumption — **CHECK WHAT ALREADY EXISTS**: installed skills and agents *(around a hundred, including all of **GSD**: `gsd-progress`, `gsd-resume-work`, `gsd-pause-work`, `gsd-review-backlog`, `gsd-capture`…)*, plugins, marketplace, native features.
> **If no system is explicitly in use on this project, look for one BEFORE building one.** *(`find-skills` exists exactly for this.)*
> **Only build custom as a last resort** — and say so.

### Structural decisions → `repo/docs/adr/`
**Versioned, immutable.** An ADR is not edited when the decision changes: **a new one is written that supersedes the old one**. What matters is preserving the **why** — which the code can't express.

### What is VERSIONED (in `repo/`), and why

| File | Role | Why it's versioned |
|---|---|---|
| **`AGENTS.md`** | Project instructions **for any agent**: commands, structure, branches, conventions, controls, do-not-touch | **A real standard** ([agents.md](https://agents.md), handed to the Linux Foundation in late 2025, read by 30+ agents: Cursor, Copilot, Gemini CLI…). **`CLAUDE.md` imports it via `@AGENTS.md`** and keeps only the **personal** bits (`workspace/` pointers, secrets, auth) → **a single source, zero drift**. |
| **`CHANGELOG.md`** | What changed **for a user** — [Keep a Changelog](https://keepachangelog.com) format, **inline link** per version (`## [X.Y.Z](…/releases/tag/vX.Y.Z)`) | The GitHub Release carries the **auto-generated PR list**; the CHANGELOG carries the **meaning**. *(Sources call this duplication superfluous solo — kept anyway, for the meaning it adds beyond the PR list.)* |
| **`docs/adr/`** | One entry per **structural** decision (stack, schema, boundary) — [Nygard](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions) format | Preserves the **why**, which the code never states. Worth it even solo (near-zero cost). **Immutable**: an outdated decision isn't edited, it's *superseded*. |

**Deliberately left out** (solo-project theater, verified): `llms.txt` (SEO fad, not a standard) · `SUPPORT.md` · `GOVERNANCE.md` · `CITATION.cff` · `ROADMAP.md` (`SUIVI.md` covers it).

**Other defaults**: eng/fr i18n with a **separate dictionary** (never inline ternaries) + parity checked in CI.

## 17. GitHub repo configuration

The whole config/maintenance spectrum for a public repo — security/code controls, **two-tier PAT matrix** (autonomous recurring / one-shot admin), OpenSSF, scriptable vs UI, new-repo checklist — is in **`github-repo-config.md`** (next to this file). It's **one-shot**: set at creation via `configure-repo.sh`, then forgotten.

In short: **CodeQL in native *default setup*** · Dependabot · secret scanning + push protection · **private vulnerability reporting** · `main` ruleset (+ `develop` if it exists) · **tag ruleset** · **immutable releases** · third-party actions pinned to SHA · minimal `permissions:`. The assistant's PAT manages alerts autonomously, **never touching `Administration: write`**.

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
- **PRIVATE repo (Free)**: default setup is **unavailable** *(GHAS required)* — exactly like the workflow was. **Nothing changes**: `Semgrep` + `osv-scanner` remain the mitigation *(see below)*.
- **CodeQL no longer "wakes up" on its own at the flip**: it's **rerunning `configure-repo.sh`** that enables it — and that rerun is **already mandatory** in the visibility-flip procedure *(§18)*. No new action.
- A **legacy** repo still carrying a `codeql.yml`: enabling it moves it to **`disabled_manually`** — GitHub refuses both modes at once. The script **says so** instead of doing it silently. **Then delete the file: an orphaned workflow is a control nobody reads anymore.**
- The check run **keeps the name `CodeQL`**: the `code_scanning` ruleset rule *(`tool: CodeQL`)* is **unchanged**, and keeps blocking PRs.

### Recommended controls (industry best practices)

| Control | What it prevents | Where |
|---|---|---|
| **Ruleset on `v*` tags** (`deletion`, `update`) | A release tag being **moved or deleted**. **Without it, the §13 version pin guarantees NOTHING**: prod pins `X.Y.Z` believing it froze an artefact, while the tag can point elsewhere tomorrow. | `configure-repo.sh` |
| **Immutable releases** *(GA 2025-10-28)* | A published release's **assets** being **replaced**. It's the counterpart of the `tags` ruleset: that one freezes the **tag**, this one freezes the **content**. Without both, the §13 pin can be bypassed **without touching the tag** — republishing a different binary under the same one. **NOT RETROACTIVE: "immutability will only apply to future releases" → set BEFORE v1.** | `configure-repo.sh` *(at the public flip)* |
| **Private vulnerability reporting** | An external researcher having **no way to report privately** — and so publishing the flaw as a public issue instead. **Without it, the `SECURITY.md` link is DEAD.** | `configure-repo.sh` |
| **`dependency-review-action`** (PR) | A vulnerable or badly-licensed dependency **getting in**. Dependabot only alerts **AFTER** merge: the two are complementary, not redundant. | `ci-node.yml` |
| **`actionlint` + `zizmor`** (PR) | **The workflows themselves** being the hole: a `${{ }}` interpolated into a `run:` is a **shell injection**. | `ci-*.yml` |
| **`persist-credentials: false`** | The `GITHUB_TOKEN` **lingering in `.git/config`** and leaking via an artefact (the `artipacked` audit). | every `checkout` |
| **`default_workflow_permissions: read`** | A **future** workflow, written without a `permissions:` block, inheriting a **write** `GITHUB_TOKEN`. Our workflows all declare it — this is a safety net, not an immediate gain. | `configure-repo.sh` |
| **Renovate `groupName`** | **Noise**: minor + patch grouped into **one** PR. **Majors stay isolated** — a major can break things, it deserves to be looked at alone. | `renovate.json` |
| **Trivy** on the image (PR) — *capability **`artefact`*** | An image carrying a **CRITICAL/HIGH** CVE reaching `main`. Scanning **at deployment is too late**: the image is already tagged and prod pins it. The **`build-check`** job is a **REQUIRED** check — otherwise the scan is **decorative**. | `docker-publish.yml` |
| **Weekly Trivy on the PUBLISHED image** — *capability **`artefact`*** | An image **already in prod** becoming vulnerable **with nothing saying so**. The PR gate no longer looks at anything after merge, and Renovate only catches up if the base image **moves**: a line of images that **stops being rebuilt** produces no bump, no PR, no scan — the CVE keeps being served. **This is a watch scan, not a gate**: it isn't required anywhere, it **alerts**. | `docker-publish.yml` |

### Who updates dependencies and pinned tools — Renovate, the sole auto-detecting bot

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

> **Pinning policy — `.github/zizmor.yml`**: full SHA required for **any third-party action**; **a major-version tag tolerated for `actions/*` and `github/*`** (compromising them means compromising GitHub itself). This isn't fussiness: in **March 2026, 75 of the 76 tags of `aquasecurity/trivy-action` were force-pushed**. A tag is mutable; a SHA is not.

**Rejected, after review**: SLSA attestations (no one else consumes the images → signing into a void) · OpenSSF Scorecard (measures *process* compliance, a gameable score) · CODEOWNERS and merge queue (multi-contributor territory).

---

## 18. Control matrix — what, where, when, by whom

> Principle: **every defect is caught as early as possible**, and each stage catches what the previous one let through.

| Stage | Controls | When | By whom |
|---|---|---|---|
| **Pre-commit** *(local)* | **gitleaks** (staged files) — **and nothing else**: no lint. *No linter is universal across the three toolchains (static has no toolchain, node depends on the project, generic is a stub to fill in): forcing an `eslint` that half the projects don't have would fail the hook on the very first commit. Lint belongs to the project, not the template.* | on every commit | dev machine |
| **Push** *(server)* | **secret scanning push protection** | on every push | GitHub |
| **PR** *(CI)* | **gitleaks** (**full** history) · **actionlint** + **zizmor** (the workflows) · **Semgrep** + **osv-scanner** *(the only ones that run in PRIVATE — see below)* · **CodeQL** *(public only)* · tests + typecheck + `npm audit` + **dependency-review** *(public only)* + **Trivy on the image** (*`artefact` capability* — **not** "node": a `static` site that publishes an image has it too) · syntax-check (`static` toolchain) | on every PR | GitHub Actions |
| **Server** | `main` ruleset (+ `develop` if it exists): PR required, **required checks (`checks` + CodeQL + `build-check` if a Docker image)**, no force-push/deletion · **`v*` tags ruleset** (no deletion or moving) **+ immutable releases** (no asset replacement) — *both, otherwise the §13 pin can be bypassed* · secret scanning · **private vulnerability reporting** | continuously | GitHub |
| **Scheduled** | CodeQL · **Dependabot alerts** *(CVE detection)* · **Renovate** *(version updates + auto-merged security remediation)* · **Trivy on the published image** *(`artefact` capability)* | weekly | GitHub · Renovate · GitHub Actions |
| **Rotation** | Write PAT — **J-14 alert** in `.envrc` (§5) | every 90 days | Claude alerts · the maintainer regenerates |

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
> **Nothing to add to the PAT** — the command below only needs `Actions: read`, already in the matrix (§5).
>
> ```bash
> sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)   # --json targets → no rollup requested
> gh run list --commit "$sha"
> ```
>
> **GREEN ⇔ ALL EXPECTED workflows are `completed / success`**: `CI`, **+ `Publish image`** if `docker-publish.yml` exists — *the same set as the ruleset's required checks, derived the same way (presence of the workflow)*, so the human barrier and the server that will replace it at the flip say exactly the same thing.
> ⚠️ **A MISSING workflow is NOT a green.** GitHub registers workflows **one by one**: for a few seconds after a push, `CI` can be `success` while `Publish image` hasn't been created yet. Settling for "nothing red" then declares the PR mergeable **while missing a check**. **"Nothing red" ≠ "everything green".**

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

A private repo gains the three missing stages **all at once** by going public → that's the moment to rerun `configure-repo.sh` (§10, step 7), **after** a `gitleaks detect` on the **full history** (§17): at the visibility flip, a secret buried in an old commit becomes public.

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
**Before a private → public switch** (§17), it's **every ref** that needs covering, not just `main`: a secret in an old pushed branch becomes public too.

### Private → public switch — **a normal step in the flow**, not a special case

**This is the nominal path** (§10): every repo is born private and later flips public. A private repo on Free has **no ruleset, no CodeQL, no secret scanning** — it gains **all of them at once** at the flip.

> ⚠️ **The flip is the most dangerous moment in a repo's lifecycle**: **the entire history goes public at once**, including a secret buried in a six-month-old commit — and it will have been pushed during the phase where **no server-side secret scanning existed at all**. Hence the gitleaks pass over every ref, below, non-negotiable.

**What the switch requires, and why** *(exact sequence — who does what, in what order: RUNBOOK §4)*:

- **`gitleaks` on EVERY ref**, not just `main`, from a **detached worktree** (§18) — a secret in an old pushed branch becomes public too.
- **Rerun `configure-repo.sh`** (**ephemeral** admin PAT): it sets the `main` ruleset, secret scanning + push protection, Dependabot, **immutable releases**, description, **topics**, **enables CodeQL** *(default setup)*, and picks the **merge method based on the `staging` capability** (squash only; + merge commit if `develop` exists — squash-only is incompatible with a staging branch, §12). The script is **idempotent**: safe to rerun.
- **Nothing to do for the workflows.** `pages.yml` carries `if: github.event.repository.visibility != 'private'`: it is **`skipped`** in private and **wakes up on its own** at the flip. ⚠️ **CodeQL, though, is NO LONGER a workflow** *(no more `codeql.yml` — §17)*: it's rerunning `configure-repo.sh` that enables it, in *default setup*, and **waits for its first analysis** before setting the `code_scanning` rule — otherwise `main` would be left unguarded.
- **ORG repo — SYSTEMATIC, never an exception**: the "Reported content" moderation setting is **UI-only** (no REST/GraphQL API) and is only applied by default to repos **created public** — so **never to ours**, born private. Without it, community health caps out. **Exact path + value: RUNBOOK §5 · github-repo-config §5.6.**
- **Then verify, read-only**: community health **100%** · CodeQL **green** · ruleset **active** · secret scanning **on**.

> **Why the workflows manage themselves instead of being added at the flip**: a manual procedure is a recurring, *forgettable* cost. A job that fails on every run on a private repo makes CI permanently red — and **CI that's always red stops being read**. The condition is written `!= 'private'` (never `== 'public'`): if the field were ever missing from the payload, the job **runs** (noise) instead of **silently disabling a security control**. **CodeQL was the exception to this principle, and it was the wrong tradeoff** — its `codeql.yml` did manage itself, but at the cost of one frozen language nobody kept updated (§17). The action already existed: rerunning `configure-repo.sh` is mandatory at the flip.

### Acquiring a CAPABILITY on an already-live repo

The repo keeps everything else: the category doesn't change, a capability is **ACQUIRED**. A Pages site that starts publishing an image **stays** a Pages site.

`init-project.sh` sets capabilities **at creation**. Here the repo already has history, rulesets, and required checks: the generator isn't rerun, capabilities are **added** — in the right order.

> ⚠️ **THE ORDER IS THE TRAP, and it's counter-intuitive.** `configure-repo.sh` makes `build-check` **required** as soon as it sees `docker-publish.yml` on `main`. Run **before** the workflow is there, it demands a check **that will never report**: every PR stays blocked forever on *"Expected — waiting for status"* — **including the one that brings the workflow**. The repo **locks itself out**.
> **→ The workflow must reach `main` BEFORE the script requires it.** This rule applies to any capability that adds a **required check**.

#### Acquiring `--artefact` — "third parties should be able to self-host my project"

*The Pages-site-plus-Docker case: a Pages page later packaged as an image so third parties can deploy it and track updates. **Pages stays**, and there is **no `develop` to create** — no host exists that needs validation.*

*(Exact sequence — who does what, in what order: RUNBOOK §5.)*

- `Dockerfile` + `docker-publish.yml` arrive **via PR**, before `build-check` becomes required — that's what avoids the ordering pitfall (above: "the order is the trap").
- **Static page → `FROM nginx:alpine`** *(a web server, not a toolchain — §14)*, **followed by `RUN apk upgrade --no-cache`.** 🔴 **This line is NOT cosmetic**: `nginx:alpine` lags behind Alpine packages and can carry HIGH CVEs already fixed upstream. Trivy runs with `--ignore-unfixed`: it surfaces **all** of them, and `build-check` goes **RED** — the template's own scanner then rejects the image the template itself recommends, without this line.
- **The base image is bumped automatically**: Renovate auto-detects the `Dockerfile`'s `FROM` as soon as it lands — **nothing to declare**. *(Without a bot bumping it, Trivy would block PRs on an image CVE with nothing proposing the fix — the control detects, nobody fixes. Renovate closes that hole by construction.)*
- **Don't touch the `## Branching` block** or create `develop`: with no host to validate, that would be an empty ritual (§12).
- Once the workflow is on `main`, rerun `configure-repo.sh`: it detects `docker-publish.yml`, requires `build-check`, sets the `tags` ruleset and immutable releases, and **verifies the image is anonymously pullable**.
- **The ghcr package can be private even if the repo is public** (§13): on a personal account it's pullable by default; on an org, it may need a manual step (UI, no API) — only make it public if the test fails.
- **Immutable releases: before v1**, never after — they aren't retroactive.
- Document self-hosting in the README with a **pinned tag, never `:latest`** (§13).

#### Acquiring `--staging` — "a host has appeared, I want to validate it before prod"

*(Exact sequence: RUNBOOK §5.)* The `## Branching` block in `CONTRIBUTING.md` **and** in `AGENTS.md` must be rewritten for 3 stages (§12) — otherwise both still advertise GitHub Flow even though `develop` exists. Pushing `develop` goes through fine: the `pre-push` hook lets branch **creation** through. Once `develop` is detected, `configure-repo.sh` sets its ruleset and **allows merge commits** on `main` — squash-only is **incompatible** with a staging branch (§12). `docker-publish.yml` already listens for PRs to `main` **and** `develop`: without that, a PR to `develop` would stay blocked forever.

#### Acquiring / removing `--pages`

**Acquiring**: copy `pages.yml`, fill in the `<web-dir>`, and create the site *(`configure-repo.sh` does it — `Pages: write`)*. No required check is added → **no lockout risk**, order is free.
**Removing**: delete `pages.yml`. **Never** leave it running "just in case" — **an orphaned workflow is a control nobody reads anymore**.

#### Removing a capability — the reverse direction

It only **removes** controls: no lockout risk… **except one**, symmetric to the ordering pitfall described above ("the order is the trap").
⚠️ **Remove `build-check` from the required checks BEFORE deleting `docker-publish.yml`.** The other way around, the check stays required while nothing produces it anymore → **every PR is blocked forever**.

### False positives: pin by fingerprint, never disable the rule
A **public** identifier shaped like a secret (contract address `0x…`/`C…`/`G…`, XDR transaction, password hash) triggers the `generic-api-key` rule. These cases are neutralized in a **versioned `.gitleaksignore`**, by **fingerprint** (`commit:file:rule:line`) and **commented** — never by disabling the rule: a **real** secret in the same file must still get caught.

---

## 19. One-sentence summary

> **One folder to back up** (`~/Documents/Claude/<project>/`), **two subfolders**: `repo/` for what goes on GitHub, `workspace/` for everything else. **One source of truth** per secret type. **Zero SSH** — reads via `gh` with a public-RO PAT, writes via a **1-repo** fine-grained PAT exposed by direnv (remote as a bare URL). **Branch + PR for infra changes**, versioned pin in prod. **With several people: one isolated working tree per person** (worktree or clone), branch protection on `main`.
