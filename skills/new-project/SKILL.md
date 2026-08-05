---
name: new-project
description: Use when the maintainer wants to create, initialise, scaffold or set up a NEW project/repo, or configure an existing one, or flip a repo from private to public, or add a capability (Docker image, staging host, GitHub Pages) to a live repo. Triggers on "initialise un projet", "crée un projet", "nouveau repo", "passe le repo en public", "configure ce repo". Drives the full runbook step by step, stopping at every action the maintainer must perform themselves.
---

# Create / configure a project — run through the RUNBOOK

## The two documents, and which one governs what

They do not replace each other — they answer two different questions. **Confusing them means either improvising the procedure, or violating the conventions.**

| Document | Answers | When to read it |
|---|---|---|
| 🎯 **`docs/RUNBOOK.md`** | **WHAT to do, in what ORDER, and WHO does it.** URLs, exact permissions, complete commands, pitfalls. | **IN FULL, before starting.** It's the thread to follow. |
| 📖 **`docs/claude-code-project-standard.md`** | **WHY**, and the **conventions to hold while developing**: layout, secrets, branches, README, lifecycle docs. | **Already imposed on every session** by `~/.claude/CLAUDE.md`. **If it hasn't been done in this session: read it NOW** — the runbook keeps referring to it ("standard §3"…), and **an unread reference is a dead reference**. |

### 🔴 Step 0 — resolve the TEMPLATE ROOT before reading anything

Every `docs/…` path on this page is relative to the **template root**: the directory holding `init-project.sh`.
That root is **two levels above this skill's own directory**, whose absolute path the runtime states when loading this skill.

**Build that absolute path first, and prefix every `docs/…` read with it.**

```bash
# <skill-dir> = the absolute path the runtime just stated for this skill
cd "<skill-dir>/../.." && pwd     # → the template root
ls "$(cd "<skill-dir>/../.." && pwd)/init-project.sh"   # must resolve
```

⚠️ **Measured, 2026-08-03 — reading `docs/RUNBOOK.md` as written resolves against the SESSION's working directory**, which is the project being created, **not** the template. It reads the wrong file or nothing at all, without an error worth noticing. `../../docs/…` fails the same way, and `${CLAUDE_PLUGIN_ROOT}` is empty here — the runtime substitutes it in configuration *(hooks, MCP, monitors)*, never in a skill's text.
**If the `ls` above does not resolve: stop and say so.** Every path below depends on it.

*(No local clone and no plugin install: <https://github.com/actarus314/project-template/tree/main/docs>.)*

> 🔴 **NEVER run through these steps from memory.** They carry URLs, exact permissions and precise pitfalls, and they change. **A step recited from memory is a wrong step.**

**Announce which version of the template is being run through, before the first step** — `./init-project.sh --version`.
This skill is a symlink into the repo, so it is always the clone's version; saying it out loud makes a stale clone visible instead of silent.

**The standard's sections actually involved here** *(to open when the runbook refers to them, not to recite)*:
**§10** initiating a project · **§16** what a project ships *(the tracking doc itself: `docs/METHODE.md`)*.
The rest lives in the files beside it: **`docs/secrets-and-auth.md`** *(GitHub auth, the PAT matrix)* · **`docs/repo-controls.md`** *(branch policy and the 3 capabilities, repo config, the controls matrix, and the procedures — flip private→public, acquire a capability)* · **`docs/security-and-updates.md`** *(who updates what)*.

> ⚠️ **In case of CONTRADICTION between the two: the RUNBOOK governs the PROCEDURE** (the order, the values, the URLs — it is kept up to date for execution). **The STANDARD governs the CONVENTIONS** (the why, the substantive rules).
> **And the contradiction must be FLAGGED to the maintainer** instead of choosing silently: two docs that diverge is a defect in the template — not a call to make in passing.

## The 4 rules, non-negotiable

### 1. STOP at every action by the maintainer

The runbook marks **who does what**. Some actions are **impossible** for the assistant (it **never** has `Administration: write` — `read` alone is allowed):
create the repo · create/revoke a PAT · `direnv allow` · run `configure-repo.sh` · flip the visibility · make a ghcr package public *(if the script's test fails)* · install Renovate.

> 🔴 **Renovate trap — the "Configure Renovate" PR** *(existing repo, app installed before `renovate.json`)*: **NEVER** merge it, and 🔴 **NEVER** close it either — it is the bot's documented, **sticky** opt-out. **Leave it open and ask the maintainer.** Mechanism and repair: RUNBOOK §1 step 8.

For each one:
- **Give the direct URL** and **the exact values** (token name, expiration, permissions one by one).
- **STOP. Wait for confirmation.** **Never** move on assuming it's done.
- Then **VERIFY** in read mode that it's indeed done, before continuing.

### 2. Ask the 3 questions BEFORE typing the command

They decide the whole architecture (`AskUserQuestion`): **(a)** site served by **Pages**? → `--pages` · **(b)** does the repo publish an image that **someone ELSE** deploys? → `--artefact` · **(c)** is there a **host to VALIDATE** before prod? → `--staging`.
**Ask them with their EXACT wording** *(table and nuances: RUNBOOK §1)* — reworded from memory, (b) and (c) get confused, and an unnecessary `develop` gets built.
Plus the **toolchain**: `--type static` (no npm) · `--type node` (npm, tests, types) · `--type generic` (no pre-wired capability — Rust, Go, C/C++, Android… ; security controls only).

> 🔴 **`develop` follows from (c) alone — never Docker, never the language** *(full rule: `repo-controls.md`, "The 3 CAPABILITIES")*.

**Do not guess these answers.** If the maintainer just says "initialise un projet", **ask**.

### 3. Invent nothing, verify everything

- **The PAT's permissions**: read them in the runbook, **state them one by one**. A missing permission **fails SILENTLY** — everything else passes, and the missing control doesn't show.
- **After each step**, verify the actual result (`gh api`, `git ls-files`, the CI) — **never assume**.
- If something doesn't match the runbook: **say so**, don't improvise.

### 4. NEVER forget to revoke the admin PAT

> 🔴🔴 **This is the step that gets forgotten, and the most dangerous one to forget** *(why: RUNBOOK §1 step 7c)*. As soon as `configure-repo.sh` is finished:
> **→ https://github.com/settings/personal-access-tokens — REVOKE NOW.**
> State the reminder **explicitly**, and **wait for confirmation**. *A reminder is not a revocation.*

## The runbook's other paths

The same skill covers:

- **§2 — day-to-day work**: `feat/` → PR → green CI → merge. ⚠️ In private, **nothing requires CI** — it's the **only point that stays human**. Verify via `sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)` then `gh run list --commit "$sha"` — **never `gh pr checks`** (guaranteed 403, `Checks` permission absent from fine-grained PATs). ⚠️ A workflow **absent** from the list is **not** a green. Detail: RUNBOOK §2.
- **§3 — publishing a release**: CHANGELOG → tag `v*` → Release + image. ⚠️ **1st release: VERIFY that the ghcr package is pullable** *(`configure-repo.sh` tests it itself)* — pullable right away on a personal account, potentially private by default on an org; act only if the test fails.
- **§4 — flipping private → public**: **the most dangerous moment of the lifecycle** (the entire history becomes public all at once). Follow the 8 steps **in order**, starting with `gitleaks` on **all refs**.
- **§5 — acquiring a capability** on a live repo. ⚠️ **The ORDER is a trap**: the workflow must reach `main` **BEFORE** `configure-repo.sh` requires `build-check` — otherwise **the repo locks itself out**.
- **§6 — maintenance**: Dependabot and Renovate autonomously. 🔴 **SECRET SCANNING alerts are reserved for the maintainer.**

## Lifecycle docs — SEARCH BEFORE BUILDING

The template defaults to placing `SUIVI.md` in `workspace/docs/` *(the state AND "what's left")*.
**This is a DEFAULT, not a dogma** — `init-project.sh --no-lifecycle-docs` omits it.

> 🔴 **Every project is initialized by this template, even ones later run by a third-party system** — imposing our tracking files would collide with theirs. Why: `docs/METHODE.md`, "The tracking doc — a PRINCIPLE, not mandated files".

**To do, at project-creation time:**

1. **ASK** the maintainer whether the project will be driven by a management system *(GSD, superpowers, other)*.
   - **Yes** → `--no-lifecycle-docs`. **This system carries the principle**, our files would be a duplicate.
   - **No / doesn't know** → apply the default *(`SUIVI.md`)*.

2. 🔴 **If NO tool is explicitly named — SEARCH FOR WHAT EXISTS BEFORE BUILDING ONE** *(why: `docs/METHODE.md`)*.
   **~100 skills are installed**, including all of GSD *(`gsd-review-backlog` · `gsd-capture` · `gsd-docs-update`… among others)* — **use `find-skills`**, and also check the **agents**, the **plugins**, the **marketplace**, the **native features**.
   **Only build custom as a last resort, and SAY SO.**

> **The principle itself holds regardless of which tool carries it** *(`docs/METHODE.md`)*:
> a **CONCISE** resumption doc that **REFERS** to the detail · a **BRIEF** backlog that **POINTS** to a plan · **what's delivered is PURGED**.
> *A tracking doc that no longer gets reread no longer tracks anything.*

## Secrets discipline

- **Never rewrite a file holding a secret by line position.**
- Testing that the PAT is loaded, storage (`repo/.envrc` only), forbidden items (`.env`, remote URL): **never display a PAT in the clear** — detail and command: RUNBOOK §1 step 4.

## The `direnv allow` trap

> 🔴 `init-project.sh` placed a `direnv allow` on an EMPTY `.envrc`; pasting the PAT into it **revokes** that authorization silently. **State this explicitly**, then verify that the PAT is loaded. Symptom, command and full detail: RUNBOOK §1 step 4.
