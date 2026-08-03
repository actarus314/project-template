# Secrets & Auth — <project>
> **Personal file, outside Git. NEVER commit it, copy it to `repo/`, or share it.**

---

## 1. Default GitHub read + Git auth (`gh` CLI, public-RO)

`gh` CLI configured once per machine with a **fine-grained "Public repositories (read-only)"** PAT: read access to all of public GitHub at 5000 req/h, **no access to private repos**. Token deliberately harmless (a leak gives nothing more than what is already public).

Writing (push/PR) does NOT go through this token — it comes from the repo's PAT, exposed by direnv (see §2).

**Setup (once per machine):**
```bash
brew install gh direnv
# Create a fine-grained PAT "Public repositories (read-only)" at
# https://github.com/settings/personal-access-tokens
#   Resource owner = <the account> · Repository access = Public repositories (read-only)
#   Account permissions = none · expiration = NONE (accepted: RO on public data, a leak
#   only grants access to what is already public — see `docs/secrets-and-auth.md`. WRITE PATs, on the other hand, are 90 days.)
echo "<PAT-public-RO>" | gh auth login --with-token
gh auth setup-git        # git delegates its auth to gh (helper "gh auth git-credential")
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc   # direnv hook
```

**Verification:**
```bash
gh auth status
gh api rate_limit --jq .rate     # "limit" should be 5000
gh api repos/<owner>/<a-private-repo>   # should return 404 (private inaccessible = OK)
```

---

## 2. Repo write PAT (push, PR, issues) — 1 per repo, via direnv

**Token**: fine-grained, **restricted to THIS SINGLE repo** (owner = repo's account or org).
**Value**: in `repo/.envrc` as `GITHUB_PAT` — nowhere else, **never in the remote URL**.
**Regeneration**: https://github.com/settings/personal-access-tokens
**Repository access**: Only select repositories → this repo only.
**Permissions (uniform standard — full matrix: `docs/secrets-and-auth.md`)**:
  - Contents: Read & Write
  - Metadata: Read (mandatory / automatic)
  - Pull requests: Read & Write
  - Issues: Read & Write
  - Workflows: Read & Write (essential as soon as there is a `.github/workflows/`, otherwise push rejected)
  - Actions: Read & Write (CI status + re-run/cancel a run)
  - Dependabot alerts: Read & Write (view + dismiss/reopen autonomously)
  - Code scanning alerts: Read & Write (view + dismiss autonomously)
  - Secret scanning alerts: Read (dismiss reserved for the maintainer — wrongly dismissing a real leak = too much impact)
  - Administration: **Read** (NEVER write) — verify the security settings a script's `✓` claims
  - **Everything else: No access** — `Administration: WRITE` reserved for the maintainer's ephemeral admin PAT

**Duration**: **90 days** (`docs/secrets-and-auth.md` — every new PAT).
**Last generated**: YYYY-MM-DD
**Expires on**: YYYY-MM-DD

> **Automatic alert**: `.envrc` warns in the terminal **14 days before** expiration (it reads the `GitHub-Authentication-Token-Expiration` header, 1 call/day max).
> Expiration is therefore never hit mid-session — but **remember to update the new date here** after each rotation.

**Exposure to git/gh via direnv.** The remote stays a **bare URL** (`https://github.com/<owner>/<repo>.git`). The PAT is made visible to git/gh **only in this folder**, via direnv:
- `repo/.envrc` (gitignored) contains the PAT and stays **sourceable in bash** (no `dotenv` builtin, for the non-interactive Bash tool):
  ```
  set -a; [ -f .env ] && . ./.env; set +a   # loads app vars from .env (bash equivalent of `dotenv`)
  export GITHUB_PAT=<PAT 1-repo>
  export GH_TOKEN="$GITHUB_PAT"
  ```
- `direnv allow` once. Entering the folder → `GH_TOKEN` loaded → `git push`/`gh` use the repo's PAT. Leaving it → back to public-RO.
- **Claude's Bash tool (non-interactive)**: direnv does not load on its own → **prefix with `direnv exec . git …`** (from `repo/`; `direnv exec` does not change the CWD, requires `direnv allow`).

**Usage:** no more need for `source .env` — direnv loads everything automatically in the folder.
```bash
git push                                   # auth via the repo's PAT (direnv)
gh pr create --title "..." --base main
gh issue list
gh run list
```

---

## 3. Application API Keys

All stored in `repo/.env`. **A single source of truth, no duplication elsewhere.**

| Variable | Service | Where to regenerate |
|---|---|---|
| `...` | ... | ... |

---

## 4. Checklist in case of compromise

If a key is exposed (accidental commit, leak, public chat, etc.):
1. **Revoke immediately** on the relevant service's dashboard.
2. **Regenerate** a new key.
3. **Update** `repo/.env`.
4. **Restart** the app (or `docker compose up -d` if containerized).
5. **Check** the logs for suspicious activity in the last few hours.

---

## 5. Reminder: what lives where

| Data | Location |
|---|---|
| Public read PAT (`gh` default) | macOS keychain (via `gh auth login --with-token`) |
| Repo write PAT (1-repo) | `repo/.envrc` (`GITHUB_PAT`, gitignored) |
| PAT → git/gh bridge | `repo/.envrc` (`export GH_TOKEN=$GITHUB_PAT`) |
| Application API keys | `repo/.env` |
| Claude Code permissions | `repo/.claude/settings.local.json` (outside Git) |
| Project instructions for Claude | `repo/CLAUDE.md` (outside Git) |
