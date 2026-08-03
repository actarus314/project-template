# Changelog

What this repo changes **for whoever uses it** — that is, for whoever generates a project with
`init-project.sh`, configures it with `configure-repo.sh`, or follows the standard and the RUNBOOK.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> **The version is the git TAG, not a heading here.** A ruleset makes a `v*` tag immutable, whereas
> any heading in this file can be rewritten in any pull request — so the tag is what a reader,
> a script or a generated project can trust *(the why: standard §12)*. `verify-version.sh` fails the
> build if this file and the newest tag ever disagree.
>
> `Unreleased` is the open section, never closed. It is sealed into a dated `## [X.Y.Z]` heading the
> day the tag is pushed — never before, so no release is ever announced that does not exist.
> Each entry carries the **meaning** of a change; the detail lives in the pull requests, and the story
> of the closed stages lives in `../workspace/archives/`.
>
> ⚠️ **This file starts on 2026-07-28.** What came before was not reconstructed — doing so from
> memory would have produced a plausible but false history. For this period: the PRs and the
> archives are authoritative.

## [Unreleased]

### Changed

- **The standard is being split by SUBJECT — one subject, one file, one owner.** It had grown to
  1012 lines and covered ten subjects it shared with three satellite documents, none of which owned
  a subject of its own: they restated §5, §12, §17 and §18. Competing sources is exactly what
  `METHODE.md` forbids, and the standard was the largest instance of it in the repo.
  **This batch moves the first three families out**: `secrets-and-auth.md` *(§4, §5 and the PAT
  permission matrix from `github-repo-config.md` §2)*, `claude-code-setup.md` *(§6, §7, §8 and the
  delegation rule from `METHODE.md`)*, and `docker-hardening.md` *(§14)*.
  🔴 **The section NUMBERS are unchanged**: every section that moved is kept in the standard as a
  one-line pointer, so a reference to "standard §5" written in an archive, a memory or a past pull
  request still resolves. The standard becomes the index of what it no longer carries.

- **`repo-controls.md` and `security-and-updates.md` stop being summaries and become owners.** Both
  used to open by deferring to the standard — *"complements §18"*, *"introduces no new rule"* — which
  is the definition of a competing source: two documents on one subject, and a reader with no way to
  know which one is stale. `repo-controls.md` now owns the branch policy, the version pin, the repo
  configuration and the control matrix *(standard §12, §13, §17, §18 + `github-repo-config.md` §1, §3,
  §4)*; `security-and-updates.md` owns who updates dependencies and pinned tools *(the Renovate half
  of §17)*. The standard keeps a one-line pointer at each number, as above.
  🔴 **A broken cross-reference was found and fixed on the way**: the version-pin section sent the
  reader to `github-repo-config.md` **§2** *(PAT permissions)* for the ghcr package UI path, which
  lives in **§4**. It had never resolved.
  Two passages that had drifted apart are now reconciled: adopting some of OpenSSF Scorecard's
  **practices** and rejecting the **tool** were stated in two files that never met, and read as a
  contradiction.

- **The standard becomes the index of what it no longer carries — 1012 lines down to ~320.** It now
  answers a single question, *where does this go?*, and opens with a table routing every other
  question to its owner. `docs/` holds **eight files, eight subjects, eight owners**.
  **`github-repo-config.md` is removed.** It owned nothing: four of its five sections had already
  moved, and the fifth was a checklist restating the RUNBOOK. Its three genuinely unique facts were
  relocated first — the list of files present from the first commit and the LICENSE decision to the
  standard, and the reason an org repo caps at 87 % *(its checklist counts 8 items, a personal
  account's 7 — so comparing the two scores means nothing)* to the RUNBOOK, next to the click it
  qualifies.
  **Standard §11 is removed**: thirteen of its entries restated §4-§8, two are held elsewhere.
  🔴 **Its last entry was not an orphan but a CONTRADICTION**: §11 said a stale `.gitignore` entry
  should be pruned periodically, §9 said leaving it in is defensive. Both are now stated once, and
  reconciled — an entry covering a path generated only inside a container stays; one that matches
  nothing at all goes.
  **The circular reference is broken.** The tracking doc was owned by nobody: `METHODE.md` named the
  standard §16 as its source, and §16 named `METHODE.md` as its source. `METHODE.md` owns it now.
  Section numbers remain stable throughout: a removed section keeps its number as a one-line pointer,
  so `standard §11` or `standard §16` written anywhere still resolves.

## [1.1.0] - 2026-08-02

### Documentation

- **Standard §12 now states that `develop` reading as "N commits behind `main`" is structural and
  correct.** The promotion's merge commit lands on `main` only, so the gap grows by one every cycle
  and `0 0` is unreachable — GitHub's banner measures graph topology, not content. The section gives
  the one measure that decides (`git diff origin/main origin/develop`) and says why every way of
  "fixing" the count is worse than the gap. Nothing said so, and the silence cost a needless
  realignment on a live repository before the measurement corrected it.

### Added

- **`verify-tone.sh` — the second person is now checked, and blocks.** The standard forbids it in
  versioned content (§1) and nothing verified it: the rule held by discipline alone until it was
  found in nine files, four of them templates shipped into every generated project. The check reads
  what is **committed** (`git grep`, so an untracked scratch file is nobody's business), and its
  exceptions are **listed and narrow** rather than a disabled rule: third-party licenses, the lines
  that state the rule itself, the "By contributing…" clause, and one verbatim quotation.
  `check.sh` **and the CI run the same script**, never a copy of its grep — two sources drift. It is
  copied into every generated project, where the same rule applies.

### Changed

- **The last four French documents are now in English, and renamed with them**:
  `docs/controles-repo.{md,html}` → `docs/repo-controls.{md,html}`,
  `docs/securite-mises-a-jour.{md,html}` → `docs/security-and-updates.{md,html}`, and
  `docs/verifier-checksums.sh` → `docs/verify-checksums.sh` — whose `--maj` flag becomes
  `--update`. Everything versioned here is now English, file names included; the entries sealed
  under `1.0.0` keep the old names, since they describe what happened then.
- **`README.md` is bilingual** — English then French, separated by `---`, as the standard requires
  of a project README (§1, §15) and as `templates/repo/README.md` already modelled. It gains the
  two sections it was missing: **Why this exists** (what the tool answers, and the three findings
  that shaped it) and **What this is not** (GitHub-only, built for Claude Code, solo-sized, no
  update path for already-generated projects, build/test still per-language).

### Fixed

- **The second person, which the standard forbids in versioned content (§1), was in it anyway** —
  both doc pairs, `SECURITY.md`, and four files that ship into **every generated project**:
  `templates/repo/SECURITY.md`, `templates/repo/.gitattributes`,
  `templates/repo/.github/renovate.json` and `templates/workflows/ci-generic.yml`. All impersonal
  now. Already-generated projects keep their frozen copy. Note that nothing in `check.sh` or the
  CI verifies this rule — it held by discipline alone, and discipline is what let it slip.
- `docs/security-and-updates.md` listed as *"left to build"* the pinned local runner and the pinned
  gitleaks hook — both shipped, as `check.sh` and `.githooks/pre-commit`. Only the per-language
  build/test stub actually remains.
- `configure-repo.sh` no longer makes a status check required without checking that a job of that
  name exists on the default branch. It derived `checks` (and `build-check`) from what the templates
  ship, never from the target repo — so on a repo whose CI names its jobs otherwise, the ruleset
  required something nothing produces and **every PR blocked forever**. The script now refuses
  before writing the ruleset, and `--dry-run` reports it without writing.

## [1.0.0] - 2026-07-31

First tagged version. The repository went public on this date: everything below had landed
before the flip, and is sealed here rather than reconstructed.

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
  🔴 **The templates of LOCAL files were first excluded, wrongly.** The reasoning — *"they are
  gitignored in the generated project, so they never reach GitHub"* — is true **of the generated
  project** and false **here**: `templates/repo/CLAUDE.md`, `templates/repo/.envrc` and
  `templates/workspace/*` are versioned in this repo *(`git add -f`)*, so they were about to go
  public in French inside an all-English repo. They are translated too.
  The **template** `README.md` is the one real exception, and it stays **bilingual by design** — its
  French half *is* the product. This repo's own `README.md` is **English only**: a French half would
  be a second copy to maintain alongside docs that are now entirely English.

### Added

- **The community health files the repo prescribes but never had** — `SECURITY.md`,
  `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE.md` and
  `.github/ISSUE_TEMPLATE/config.yml`. The template **posts these into every generated project**
  and had none of its own: "the template must eat its own food", once more.
  🔴 **`SECURITY.md` is not cosmetic on a public repo**: with `ISSUE_TEMPLATE/config.yml`, it is
  what routes a flaw to a **private advisory** instead of a public issue. Without them, the only
  channel available to a finder is to disclose it in the open.
  `CONTRIBUTING.md` is written for **this** repo, not copied from the template: no `develop`
  *(nothing to validate before production — this repo is read and run, it does not deploy)*, and
  the `open-pr.sh` rule, since a PR with zero CI runs reads exactly like a green one.

- **The repo gets a LICENSE — two, in fact, and the boundary is the point.** The tool is under
  **PolyForm Noncommercial 1.0.0**; the files it **copies into every generated project**
  *(`check.sh`, `open-pr.sh`, all of `templates/`)* are under **MIT** *(`LICENSE-MIT`)*.
  Without that exception, every project built with this tool would inherit the noncommercial
  restriction — including projects whose author never asked for it and had no way of knowing.
  🔴 **A public repo with no license is "all rights reserved"**: nobody may legally use it. This was
  therefore a **prerequisite** for going public, not cosmetic community health.
  ⚠️ PolyForm Noncommercial is **not open source** *(the OSI definition forbids restricting the field
  of use)* and GitHub displays it as **"Other"** — measured on a real repo, not assumed. The community
  profile still counts the file, so the score is not penalised.
  **Generated projects default to PolyForm too**, and `init-project.sh` now says so plainly at the end
  of a run: the default forbids commercial use, and swapping `LICENSE` is a one-file decision best
  made before the first release.

- **The repo is VERSIONED — and the single source is the git TAG.** `init-project.sh`,
  `configure-repo.sh` and `docs/verifier-checksums.sh` gain `--version`; none of them stores a
  literal, all three read `git describe`. The tag is authoritative because a ruleset makes it
  **immutable**, whereas a `VERSION` file or a heading in this changelog can be rewritten in any
  pull request *(the why: standard §12)*.
  **`verify-version.sh`** compares the places that must, by nature, carry a copy — this file, each
  script's `--version`, and a plugin manifest the day one exists. Wired into `check.sh` and into a
  CI job, both auto-detecting, so a generated project is unaffected.
  ⚠️ **The CI job fetches tags explicitly**: `actions/checkout` fetches none by default, and a guard
  that cannot see the tag would pass by being blind — the exact false green this repo exists to catch.
  🔴 **Proven red, then green**, not merely written: a tag without its changelog section fails, a
  version hardcoded back into a script fails, and the guard stays a silent no-op until the first tag.

- **A generated project now says WHICH template version built it** — `AGENTS.md` carries
  `Scaffolded by project-template <version>`. A generated project holds a **frozen copy** of the
  templates, and until now nothing said which one, so no one could tell whether a later fix had ever
  reached it. The stamp is a snapshot: it stays true about the past, and it does not pretend to
  track the template afterwards.

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
