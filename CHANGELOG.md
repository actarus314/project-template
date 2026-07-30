# Changelog

What this repo changes **for whoever uses it** — that is, for whoever generates a project with
`init-project.sh`, configures it with `configure-repo.sh`, or follows the standard and the RUNBOOK.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> **No versions here, and that's intentional.** This repo has neither tag nor release: it doesn't
> deploy, it is **read** and it is **run**. So there is only one `Non publié` section, which is never closed.
> It carries the **meaning** of the changes; the detail lives in the pull requests, and the story of the
> closed stages lives in `../workspace/archives/`.
>
> ⚠️ **This file starts on 2026-07-28.** What came before was not reconstructed — doing so from
> memory would have produced a plausible but false history. For this period: the PRs and the
> archives are authoritative.

## [Non publié]

### Changed

- **The repo switches to ENGLISH, and the standard's §1 language exemption FALLS.** That exemption
  rested on three legs — a **private** repo, no contributor sought, and English buying nothing but a
  translation to maintain. Going public removes one of them, and the call was made to align the repo
  with what it already imposes on every project it generates. **What it teaches does not change**:
  every lived example was rewritten without the real repo name, the lesson kept.
  Landed in batches: the conventions *(`claude-code-project-standard.md`, `METHODE.md`,
  `github-repo-config.md`, `AGENTS.md`)*, then the RUNBOOK and the `new-project` skill, then the root,
  the scripts and the workflows. **The `.md`/`.html` pairs are still to come, so the repo stays mixed
  until they land.**
  Templates of **local** files *(`templates/repo/CLAUDE.md`, `templates/repo/.envrc`,
  `templates/workspace/*`)* **stay in French**: they are gitignored in the generated project and never
  reach GitHub. The **template** `README.md` stays **bilingual by design** — its French half *is* the
  product. This repo's own `README.md`, by contrast, is **English only**: a French half would be a
  second copy to maintain alongside docs that are now entirely English.

### Added

- **A drift guard between `docs/X.md` and `docs/X.html`** — nothing prevented a `.md`
  *(the source of truth)* from evolving without its hand-made `.html` layout following along, and this had already
  happened. `docs/verifier-checksums.sh` compares the sha256 of the `.md` to the one recorded in the
  header comment of the `.html`; divergence → red, with the update command
  (`--maj`). Wired into `check.sh` *(auto-detected: silent if the script is absent, so
  no impact on a generated project)* and into a dedicated job in `ci.yml`.

- **A WEEKLY Trivy scan of the published image** *(`artefact` capability)* — `docker-publish.yml` gains a
  `scheduled-scan` job. Until now the image was only looked at **on the pull request**: after the merge, nothing
  more. Renovate only catches up if the base image **moves** — but a line of images that **stops being
  rebuilt** produces no bump, no PR, no scan, and the image in prod keeps serving the CVE *(this is
  what left a frozen `debian12` base publishing a CRITICAL openssl for months)*. Same flags as
  `build-check`: **a single criterion of "clean" per file**. ⚠️ **A `schedule` only runs from the
  default branch**: on a 3-stage project, a PR that stops at `develop` arms nothing.
  ➡️ The check: `docs/controles-repo.md`; the why: **standard §17**.

- **`AGENTS.md` learns to check the `push` run on `main` AFTER a merge** — a different event, so
  a different run: a PR's green tells nothing about that one, and it's `main` that ships. The check
  was prescribed **nowhere** in the versioned files. It comes with its trap: the command already
  documented does not find that run. ➡️ The rule and the command live in `AGENTS.md`
  *(template: `templates/repo/AGENTS.md`)*.

- **The working PAT gains `Administration: read`** *(never `write`)* — without it, the assistant cannot
  **verify** the settings a script claims to have applied: neither the security toggles, nor the
  **classic** branch protection *(invisible in the `rulesets` API, and able to lock `main` forever)*.
  Two outages already experienced, structurally undetectable without this read access. It doesn't mutate
  anything. ➡️ Derivation and endpoints: **`docs/github-repo-config.md §2`**; checkbox:
  **`docs/RUNBOOK.md §1`**. **On an existing PAT, no rotation is necessary** — the UI edits the
  permissions in place.

- **The `new-project` skill enters the repo**, as the **canonical** version — `skills/new-project/`, with
  `~/.claude/skills/new-project` reduced to a **symlink**. It runs through the RUNBOOK but used to live outside any
  repo: neither versioned, nor run through CI, nor diffable. It is at the **root**, never under
  `templates/`: nothing here duplicates into the generated projects.

### Fixed

- **The incident justifying PR-even-when-solo lived only in `docs/controles-repo.html`** — the
  `.md` carried only a cross-reference ("standard §12"), the story itself only existed in the copy.
  Brought back into the `.md`, in anonymized form: no more project name or host name.
  `docs/controles-repo.html` also had a hardcoded revision date removed: absent from the `.md`,
  already stale — exactly the kind of fact that drifts silently.

- 🔴 **Two templates named PRIVATE repos, and kept copying themselves into every generated project** —
  `ci-node.yml` referred to a real repo *"for a worked example"*, `templates/repo/README.md`
  cited another one. A template is not internal prose: it **goes out** into the projects, **including
  public ones**. The name of a private repo was therefore readable by anyone on a public generated project,
  with nothing flagging it. Both references are replaced by what they **taught**
  *(an `npm ci --prefix <dir>` per workspace)* or removed. ➡️ **A project generated before this fix
  carries a frozen COPY: the propagation is part of the fix.**

- **`configure-repo.sh` announced "✓ Discussions open" without ever checking that they were.**
  It tested the **exit code** of the `PATCH /repos` call — but `has_discussions` is not a documented
  body parameter of that endpoint, and REST **silently ignores an unknown field**: the PATCH returns 200 while
  activating nothing, and the ✓ shows up for a setting that was never applied. It now **re-reads** the repo and
  says "⚠ Discussions STILL closed" with the settings URL when that's the case. *(Same discipline as everywhere
  else in this script: a displayed ✓ is not an applied setting.)*
  ➡️ **Consequence to know**: `project-template` itself has `has_discussions: false` — so
  its "Question / Discussion" link is a 404 until the script is replayed there.

- 🔴 **The RUNBOOK prescribed CLOSING a Renovate onboarding PR** — but closing is the bot's
  **documented opt-out**. It asserted two facts that reality disproved: "Renovate restarts on its own
  as soon as it sees the file" and "reversible both ways". **The `disabled` status lives on Mend's side**,
  committing `renovate.json` afterward reactivates nothing, and the fix requires a **manual scan on the portal**.
  This is the instruction that left **4 repos with no update bot for 6 days** on 2026-07-14. Fixed to
  "leave it open and ask", along with the fix. *(The fact had already been corrected elsewhere — not here.)*

- **The `new-project` skill recommended `gh pr checks`**, formally forbidden in this repo *(the
  `Checks` permission does not exist in the fine-grained PAT UI)*, and still set up a **`BACKLOG.md`** that the
  template no longer generates. Plus 3 drifts: `--type generic` missing, "never `Administration`" without
  `write`, and the ghcr package presented as a systematic action instead of a conditional check.

- **The PAT recipes announced STALE permissions — in 4 places, 2 of which are read at the moment of
  creating the token** *(`configure-repo.sh` before the masked input, and step 5 of `init-project.sh`)*.
  They listed 4 permissions where the admin recipe counts 6: neither `Contents: read` nor
  `Issues: read` had been carried over, and **a missing permission raises no error**.
  Both scripts now **point** to the RUNBOOK instead of copying it — a list corrected
  today would drift at the next permission, which has already happened twice in a row.
  ➡️ The executable recipe lives in **`docs/RUNBOOK.md` step 7a**, its derivation by endpoint in
  **`docs/github-repo-config.md` §2** *(where the `Issues: read` line was also missing)*.

- **"never `Administration`" was now saying something false** — the working PAT carries `Administration: read`.
  The phrasing is made precise as **`Administration: write`** everywhere it lived *(RUNBOOK, standard,
  README, AGENTS, both scripts, the checklist)* — the RUNBOOK even contradicted itself from one section
  to another. And the working PAT recipe, in the standard, did not mention the new permission.

- **On a 3-stage flow, Dependabot also targeted PRODUCTION** — and for it, no option fixes
  that: its **security** PRs **always** target the default branch *(`target-branch` only
  redirects version updates)*. The safety net meant to protect `main` was therefore bypassing it,
  by skipping staging. `configure-repo.sh` no longer **sets it up** on a 3-stage flow, and **removes**
  the one already in place — but **only if Renovate is proven alive** *(Dependency Dashboard updated
  less than 14 days ago)*. Without the proof it **keeps** the safety net and **names the cause**:
  missing permission, app not installed, or bot stopped. Removing the net while betting on a dead bot
  is the July outage; a dashboard that **exists** proves nothing, a `disabled` repo keeps its
  own. ➡️ The why and the threshold: **standard**, "Who updates dependencies and pinned tools".

  🔴 **Two actions follow from this, both in the RUNBOOK:** the **ephemeral admin PAT gains
  `Issues: Read`** *(without it the proof of life is unreadable, and the net stays in place)*; and on a
  3-stage project, **`configure-repo.sh` is replayed AFTER the Renovate app is installed** — run
  before that, it can find no dashboard.

- **On a `--staging` project, Renovate was targeting PRODUCTION.** For lack of `baseBranchPatterns`, the
  bot targeted the **default** branch: each of its PRs — **security** ones included — landed
  on `main`, skipping the host that the third stage exists to validate. `init-project.sh` now
  sets the key on `develop`, **and only when the branch exists**. ➡️ The why, and
  why the key is injected rather than carried by the template: the `description` block of
  `templates/repo/.github/renovate.json`.

### Changed

- **`configure-repo.sh` no longer sets `delete-branch-on-merge` on a PRIVATE 3-stage repo.**
  The setting targets the **source** branch of any merged PR — so `develop` itself, when a
  promotion merges. In public the `develop` ruleset (the `deletion` rule) prevents it; in private on
  a Free plan no ruleset exists, and the branch disappeared without a word. What is lost:
  the automatic cleanup of `feat/*` — one click. Switching to public restores the setting on
  the next replay of the script. *(PR #42.)*
- **The `ci-node.yml` and `docker-publish.yml` templates now apply to a repo whose
  manifests are not at the root, and to images a third party deploys.** `ci-node.yml` refuses
  to turn green when its npm steps have been silently skipped; `docker-publish.yml` attaches
  an SBOM and SLSA provenance, and signs the image with cosign **by digest**. `configure-repo.sh`
  opens Discussions, without which the issue template link is a 404. Both templates
  warn that a `strategy.matrix` renames a REQUIRED check and blocks the PR forever.
  *(PR #41.)*
- Pinned CI tools: `zizmor` 1.28.0, `semgrep` 1.171.0, `docker/login-action` v4.5.2. *(PR #40.)*

### Added

- **This file.** The standard requires a `CHANGELOG.md` for every generated project, and this repo did not
  have one — a gap from its own rule, found while catching up another project's.
