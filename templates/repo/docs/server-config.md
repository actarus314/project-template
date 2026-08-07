# Server configuration — `configure-repo.sh`

What protects a repository does not live in its code: it lives in GitHub's settings. This project ships `./configure-repo.sh` so that it can set them itself, without needing the template it was generated from.

**Replay it every time the repository changes status** — it is idempotent, and it reports what it found as much as what it set.

```bash
./configure-repo.sh <owner>/<repo> '' 'One-line description.' 'topic-a,topic-b'
./configure-repo.sh <owner>/<repo> --dry-run     # says what it would write, writes nothing
```

## Why a replay is mandatory when going public

While the repository is **private on a Free plan**, rulesets, secret scanning, private vulnerability reporting, Pages and CodeQL are **unavailable**. The first run did not fail on them — it **skipped**
them, and said so. **Flipping the visibility arms none of them.** Without the replay, a public repository sits with `main` unprotected and no secret scanning, exactly when it starts being visible to everyone.

The same applies to gaining a capability: a staging branch, or a published image. The rules that apply differ, and the script reads what the repository actually publishes to decide.

## Step 1 — create the EPHEMERAL admin PAT

**→ https://github.com/settings/personal-access-tokens/new**

The token used day to day does **not** carry `Administration`, on purpose. This one does, so it is created for the run and destroyed after it.

| Setting | Value |
|---|---|
| **Token name** | `admin-<repo>-disposable` |
| **Expiration** | the shortest available (7 days) — it gets revoked within minutes anyway |
| **Repository access** | ⚠️ **Only select repositories → this repository** |

**Repository permissions** — the complete list, derived from the endpoints the script calls:

| Permission | Level | Why |
|---|---|---|
| **Administration** | **Read and write** | `PATCH /repos` · `PUT /vulnerability-alerts` · `*/rulesets` · `PUT /immutable-releases` |
| **Pages** | **Read and write** | creating the Pages site — a workflow token can never do it |
| **Code scanning alerts** | **Read** | know whether CodeQL has produced an analysis |
| **Actions** | **Read** | 🔴 track the first CodeQL run. Without it the script cannot tell when the analysis finishes, so it **does not set the `code_scanning` rule** and `main` stays UNGUARDED |
| **Contents** | **Read** | detect `pages.yml` / `docker-publish.yml`, and read `CONTRIBUTING.md` to know whether this repository runs a staging stage |
| **Issues** | **Read** | date Renovate's *Dependency Dashboard*, to tell a live bot from a dead one before removing the Dependabot safety net |
| *Metadata* | *Read* | *automatic* |

> 🔴 **`Administration` alone is NOT enough, and every missing permission fails SILENTLY** — not with an error, with a step that quietly does nothing. That is why the list above is complete rather than short.
> **The token is stored nowhere**: no keychain, no `.envrc`, no shell history. The script asks for it as masked input.

## Step 2 — run it, and read what it says

The script tells apart "unavailable here" from "failed": on a private repository it names what it deferred to the flip. A `--dry-run` first is always safe, and is the right reflex on a repository that already has settings.

## Step 3 — 🔴 REVOKE the token. Now.

**→ https://github.com/settings/personal-access-tokens**

That token can **delete this repository and change its visibility**. Revoking it is part of the gesture, not a tidy-up for later.

## What the script will never do

- **It does not flip the visibility.** That is a human decision made in the GitHub UI, and it is irreversible in practice: the history becomes public, and rewriting it afterwards does not un-publish what has already been fetched. 🔴 **Run `gitleaks` over ALL refs before flipping** — a secret in an old pushed branch becomes public with the rest.
- **It does not delete a protection it did not set** — a classic branch protection, a bypass actor.
  It reports them, because destroying a protection is the maintainer's call.
- **It cannot make a published package public.** Package visibility is not reachable by API; the script tests an anonymous pull and says whether the image is genuinely pullable.
