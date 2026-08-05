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

### Added
- **A check for FRENCH left in published content** *(`checks/verify-language.sh`)*. Nothing looked
  for it: `verify-tone.sh` hunts the second person, never the language, so a paragraph written
  entirely in French passed it without a murmur — and two words shipped into published documents
  that way, spotted by the maintainer rather than by a control.
  🔴 **The signal is the ACCENT, and the limit is stated instead of hidden**: unaccented French goes
  straight through, and the verdict says so in those words rather than claiming the language is
  covered. Measured before it was written: of 90 accented lines here, 65 are the two bilingual
  READMEs, 16 the French tracking doc the generator writes into the workspace, 8 the French
  patterns the checks must spell out, 1 the skill's trigger phrases — four classes, each with a
  reason that already existed elsewhere.
  **The exceptions are DETECTED, never listed**: a `# … (français)` heading opens a bilingual
  README's French half; a heredoc redirected into `workspace/` writes the French side by
  construction; quoted material is verbatim; and `fr-pattern` is **verify-tone.sh's existing
  marker**, reused rather than doubled. `repo/` only — English is a rule of published style, so it
  stops where publication stops.
- **It found a defect on its first run.** `templates/repo/README.md` opened with a **French block
  of instructions**, shipped into every generated project. Translated.

### Changed
- **`verify-growth.sh` reads its two revisions in four calls instead of two per file** — 0,88 s →
  0,17 s, **5,1× faster**, and the verdict is identical at four thresholds *(8, 5, 3 and 0
  documents reported)*. It forked `git show` **and** `git cat-file -s` once per document: 585 ms of
  pure process startup for 24 files, against 40 ms for the bulk calls that replace them.
  🔴 **`git cat-file --batch` was the obvious route and was rejected**: its stream interleaves
  headers with raw bytes, no awk can skip a byte count, and one file without a trailing newline
  shifts every object after it. `ls-tree -l` and `git grep -c` give the same two numbers with
  nothing to parse — verified equal on all 24 documents before the swap.
- **`verify-version.sh` asks its eighteen scripts in parallel** — 0,52 s → 0,27 s. The answers land
  in files, never on a shared pipe: interleaved writes are what makes a parallel loop attribute one
  script's version to another.

### Fixed
- **The control journal's page never said whether the journal was still running.** The state was
  printed to the terminal alone, so `CONTROLES.md` carried no trace of it — and its timestamps are
  those of the RECORDS, not of the reading. A page whose newest record is a day old could not tell
  *"recording stopped"* from *"nothing has run"*: two different facts, one indistinguishable line.
  The page now states which one it is, on its own line.
- **Seven controls had no duration at all in the journal** — `travelling paths`, `gitleaks`,
  `shellcheck`, `actionlint`, `zizmor`, `osv`, `renovate`. Only the parallel lot was timed, so
  everything outside it showed a bare `—`, which reads as *free* rather than as *unmeasured*, and
  no curve can be drawn through a dash. They run on the same clock as the lot now.
- **`verify-comment-drift.sh` never crossed into the neighbouring `workspace/`**, unlike its twin
  `verify-narrative.sh`. "A comment says only what the code cannot" is a rule of METHOD, and
  METHODE's discriminator sends those into the workspace too — the exemption was nothing but an
  oversight, and it would have gone on looking exactly like a clean result. **Both repositories
  now, and the count of files read in each is published**: "workspace/" in a verdict says which
  tree was *intended*, only a count says whether anything of that kind was there.
- **`verify-echo.sh` reported nothing about a group that came back clean.** With pairs found in one
  group the others vanished from the output, so `workspace/ ` clean and `workspace/` never opened
  produced the same silence — the *"publish what was read"* correction never applied to this file.
  It now prints what each group held **whatever the verdict**, and drops the *"in either
  repository"* claim it made even with no neighbour present.
- **`verify-workspace.sh` was blind to any tracking tool outside its three known names.** A
  `.linear/` dropped into the workspace left the verdict identical to a workspace holding nothing.
  Every tracked top-level dot-directory is surfaced now, minus the editor and forge ones — **named,
  never counted**: calling an unknown directory a tracking system would fire on the next editor
  that ships one, and a guard that fires where it should not earns overrides.
- **`repo-controls.md` carried two sets of durations that disagreed.** The per-control table was
  re-measured on 2026-08-05; the prose two sections below was not, and still announced
  `verify-echo` at 1,36 s after it had been made **7× faster** (0,25 s), ranked it second-slowest
  when it had become the slowest-but-four, and trailed the **tail of a replaced sentence** —
  starting mid-clause on `not add up:` — putting the gate at *"about 3,7 s"* two lines under the
  3,05 s just stated. The `.html` render carried the same stale text.
- **The control journal was documented in the CHANGELOG and nowhere else**, while `AGENTS.md`
  states that what the controls cost lives in `repo-controls.md` *"and nowhere else"* — so the
  instrument that now produces those numbers was missing from the document that owns them. It is
  there now, with the one fact that keeps the two figure sets from reading as a contradiction:
  **the table times a check alone, the journal times it inside the parallel lot** *(measured:
  `verify-growth` 0,88 s against 1,10 s)*.

### Added
- **`./check.sh --report` — a control journal, and a DEVELOPMENT instrument.** It answers two
  questions a green tick never does: **how long each control costs**, and **whether its gate ever
  fires**. A control that is only ever skipped is the failure this repository knows best — shipped,
  executable, never run — and a journal recording only verdicts cannot show it, because the line
  simply is not there. Skips are therefore recorded too, with the gate that decided.
  🔴 **OFF by default**: nothing is written until `--report --on`, and the cost when off is one file
  test per verdict. `--off` stops it, `--reset` clears it. The record lands under `.ci-tools/`
  (gitignored) — local telemetry, never repository content — and the view is written to
  `workspace/docs/CONTROLES.md`. Written by `check.sh` at the single point every verdict passes
  through, so no list of controls has to be kept anywhere.
- **Every check now travels into a generated project, and every check has a gate there.** A project
  received three of the eighteen, and **no generated workflow called any of them**: the checks
  shipped, ran locally at best, and gated nothing. `init-project.sh` copies `checks/` whole, and
  each project's `ci.yml` carries one line — **`./check.sh --house`** — behind which everything
  under `checks/` runs. Adding a check is dropping a file in: no list to update, no workflow to
  edit, in any project.
- **`./check.sh --house`** — the house checks and nothing else. The external tools *(gitleaks,
  semgrep, osv-scanner, actionlint, zizmor)* stay the CI's own steps, at the versions it pins and
  checksums; replaying them inside the same job would download and rerun the lot for one verdict.
- **`verify-checks-wiring.sh` guards the gate itself**: the line missing from any gating workflow
  — this repo's `ci.yml` or the three shipped templates — fails the build. It also compares the
  hooks the table calls `n/a` against the ones the runner actually keeps out, closing the gap it
  used to state about itself.

### Changed
- **`verify-echo.sh` stopped reporting the very shape the rule prescribes.** A paragraph that LINKS
  to another document is the pointer METHODE asks for, not a copy — and a good pointer names what it
  points at, so it shares that document's vocabulary by construction. Three of the four last pairs
  were exactly that. Pointers are now excluded, and the French detector recognises short technical
  prose *(a bilingual README's French half was reading as English and being compared with its own
  English half)*. **34 pairs → 0**, and a planted copy still scores 1.00.
- **The three advisory checks now BLOCK** — a warning nobody must act on is a warning nobody reads.
  Two tunings came with it, each measured: `verify-comment-drift` gained a **floor in lines** beside
  its percentage gap *(percentages alone over-report a small file: +134 % of comment against +94 %
  of code was 34 added lines against 36)*, and `verify-echo` excludes `CODE_OF_CONDUCT.md`,
  third-party text whose graduated sanctions restate each other by design.
- **`verify-echo.sh` is 7× faster** — 1,78 s → 0,25 s, verdict strictly identical. It computed the
  language of a paragraph once per PAIR inside a quadratic loop; it is computed once per paragraph.
  That check was the floor of the CI gate, which now runs in **3,05 s**.
- **The control table's durations were wrong by 1,7× to 4,1×.** They were single cold runs on a busy
  machine. They are medians of three now, and the note says so.
- **A hook declares itself** — `# hook: <event>` in its own header — and `check.sh` detects that
  line instead of naming the three. That was the **last hand-written list left in the runner**, and
  the one that travelled into every project with nothing to guard it: a fifth hook dropped into
  `checks/` would have joined the parallel lot and **hung on STDIN, with no output at all**.
- **A check is universal: it detects whether its subject exists where it lands.** Present, it
  bites; absent, it **says so** and returns 0. This is what made the travel possible at all — and
  what a *"which ones deserve to travel?"* list could never answer, since only the check, at the
  place, knows.
- **This repository's `ci.yml` calls the same one line**, in place of twelve hand-written steps.
  That list was one of the three that had to be kept in agreement by hand, and a check missing from
  it passed no gate at all.
- **`CONTRIBUTING.md` and `AGENTS.md` stop restating each other in generated projects.** The
  `## Branching` block was injected into **both**, and the merge-verification procedure was written
  out twice — so every project was born with the duplication METHODE forbids, in the two files that
  teach its rules. `AGENTS.md` keeps both *(it is the authority, and what an agent reads)*;
  `CONTRIBUTING.md` points at it. Measured on a generated project: **5 restated pairs → 0**.

### Fixed
- **`shellcheck` reached no generated project — neither locally nor in CI.** It was the only control
  this template ran on itself and shipped to nobody: a shell bug was blocked here and went through
  in silence over there, on both sides. One step in the three workflow templates covers both, since
  `check.sh` reads a project's `ci.yml` to decide what to replay.
- **`verify-version.sh` recognised neither Go nor Java, and its own comment claimed otherwise.** Both
  are matched now — and a **compiled** executable, which has no source to grep, is named as
  unexamined rather than silently cleared.
- **`verify-narrative.sh` swallowed unknown languages in silence**, where its twin publishes the
  list: a `.zig` holding a dated comment came back clean. It publishes what it did not read, and
  asks a file for its **shebang** when the name carries no extension — which revealed that
  `pre-commit` and `pre-push`, the hooks, were **never scanned at all**.
- **A broken interpreter printed a clean tick.** `verify-narrative.sh` swallowed its own python
  errors behind `|| true`, twice, while reading nothing.
- **Three checks still presumed the shape of the project they landed in.** Each carried a
  hand-written perimeter, which is the defect already paid for once, when a travelling check read
  ZERO files in every Python, TypeScript and Go project:
  · `verify-version.sh` looked for `--version` in `./*.sh` and `checks/*.sh` — it reads **every
  tracked EXECUTABLE** now, whatever the language, and recognises the handler in shell, Python and
  Node *(proven: a Python CLI printing a wrong version is caught, and the old perimeter never saw
  it)*;
  · `verify-echo.sh` and `verify-growth.sh` read `docs/*.md` plus three names at the root, so a
  project writing into `documentation/`, `guide/` or `wiki/` was invisible to them. They read
  **every tracked `.md`** now, minus what restating is the nature of — a CHANGELOG, an archive, a
  form template — and `verify-echo.sh` groups by the project a document belongs to, so a template's
  `AGENTS.md` echoing this repo's reads as the template working rather than as a defect.
- **One malformed JSONL line disarmed all three signals of `verify-turn-claims.sh`, in silence.**
  The `try` wrapped the whole read loop, so a single unparseable line anywhere in the turn threw
  out of it and left both lists `None`. Parsing is per line now, and a PARTIAL read splits the
  signals: the one accusing on an **absence** (nothing edited) stands down, since an unread line
  could hold the very edit; the two accusing on what is **present** keep biting. *(Planted: the
  signal fired on a healthy transcript and vanished entirely when one junk line was appended.)*
- **`verify-workspace.sh` counted tracking FILES, not tracking SYSTEMS.** A `.planning/` sitting
  beside a `SUIVI.md` — the exact collision METHODE forbids — returned the same *"1 tracking doc"*
  as a workspace holding nothing else. It now counts systems, and **names what it looked for**, so
  a reader sees which tools remain invisible to it. A project using GSD alone stays green.
- **Two checks would have FAILED in every generated project, not merely gone quiet.**
  `verify-travel.sh` demanded an `init-project.sh` no project has, and `verify-do-not-break.sh`
  demanded three `templates/repo/` files and a skill symlink that belong to the generator alone.
  Each target now detects whether it applies, and **names what it did not read**.
- **Four checks returned a silent 0 where they had read nothing** — `verify-memories.sh`,
  `verify-checksums.sh`, `verify-changelog.sh` *(four exits)*, and one target of
  `verify-do-not-break.sh`. The caller printed a tick over each: the bare ✓ this repo arms itself
  against, in the checks that carry the arming.
- **`verify-changelog.sh` carried a hand-written list of what counts as user-visible** — three
  shipped scripts, while ten travelled. The perimeter is now **detected** from what the repository
  holds, and a project holding none of it says so instead of reporting a permanent "nothing
  visible". *(A branch-name trigger was measured and rejected: 11 of the last 40 pull requests here
  carry no CHANGELOG line and are right not to.)*
- **`verify-travel.sh` reported three checks that guard their targets correctly.** It only honoured
  a shell test on the same line as the path; it now also honours a negated test, a Python existence
  test, a literal bound to a name tested elsewhere, and a tested parent folder.
- **The three hooks pointed at `docs/claude-code-setup.md`** in their own messages — a path that
  resolves nowhere once they travel. Named by URL now, which resolves from anywhere.
- **The three hooks were watched by nothing.** They live in the assistant's local settings, outside
  every repository: an entry that drops simply stops firing — no error, no trace, and the session
  reads as it always did. `verify-do-not-break.sh` now checks them, **deducing which checks are
  hooks from the table** rather than listing them. Silent when none is declared *(the documented
  inactive mode)*, loud when some are and one is missing.
- **`check.sh --commit` was blind to the neighbouring `workspace/`** — a separate git repository, so
  a diff run here never saw it. A `SUIVI.md` doubling in size woke neither `verify-echo` nor
  `verify-growth` unless a `.md` happened to move here in the same commit.
- **`verify-comment-drift.sh` counted a TRAILING comment as pure code**, blind to the very shape
  that grows a comment invisibly. Such a line now counts as one of each.
- **Two gates missed their own input**: `zizmor` watched the workflows but not its config *(which
  lives under `templates/`)*, and the Renovate validator missed the pinned version that decides its
  verdict.
- **`verify-changelog.sh` saw a `.sh` added or deleted, never one CHANGED** — while the rule it
  enforces names *"a script's behaviour"* outright. It now watches the scripts that **travel**.
- **`verify-version.sh` compared 3 scripts out of the 18 that handle `--version`.** The list is
  derived from the flag being *handled*, and an empty read fails rather than passing.
- **`verify-secret-blindspots.sh` knew `.env` and `secrets`** — a private key, an `.npmrc`, a
  `.netrc` or a service-account file are just as readable, and gitleaks reads none of them by name.
- **`verify-links.sh` read inside fenced code blocks.** Its header promised the opposite; only the
  inline pattern delivered it. It also **resolves anchors** now, which is what makes a table of
  contents safe to write.
- **`verify-travel.sh` looked at one project shape out of five.** It generated a single `--type node`
  project, so `ci-static.yml`, `ci-generic.yml` and `pages.yml` — files that never land in a `node`
  project — were read by nobody. It now generates **one project per toolchain plus one carrying every
  capability**, and the toolchains are **read from `init-project.sh`** rather than listed, so one
  added there is covered the day it is accepted. **It found a real dead path on its first run**: the
  `generic` CI template pointed twice at `docs/repo-controls.md`, which exists in the template and in
  no generated project — shipped since the docs split and invisible until now.
  ⚠️ **The cost is real and published**: 0,46 s → **1,66 s**, and a commit touching `templates/` goes
  from 2,2 s to 3,7 s. It only starts on four file paths.
- **`verify-tone.sh` no longer misses the capitalised second person.** `git grep` is case-sensitive,
  so `You can run…` and `Your project…` — the second person at the *start of a sentence*, which is
  where it lands most often — went through untouched, while the lowercase forms were caught. The
  flag found a real violation on its first run, in `templates/workflows/ci-generic.yml`, copied into
  every generic project. **This check travels**, so every generated project was equally blind.
- **A check whose verdict `check.sh` dropped.** `verify-checks-wiring.sh` was started with the
  others and no block read its result back: a check deleted from `checks/` left the local lot
  **green** while the CI, running the same file, went red — against the one promise `check.sh`
  makes, *local == github*. It cannot catch this class itself: it compares the table against
  `ci.yml` and `init-project.sh`, never against `check.sh`.
- **A failing check now prints its own error.** The subshell that captures each result inherited
  `set -e`, so a check exiting non-zero died *before* writing its return code — and the missing file
  was then reported as **"it never ran"**, with the real message left unread in the capture. Every
  failure looked alike, and a genuine never-ran became indistinguishable from an ordinary red.
- **A check no longer claims a perimeter it did not read.** With the neighbouring `workspace/`
  renamed away, `verify-links.sh`, `verify-secret-blindspots.sh` and `verify-growth.sh` still
  announced *"in both repos"*. Each now names what it read **and what it did not**, and
  `verify-workspace.sh` says so out loud instead of exiting mute. An absent root, a glob matching
  nothing and a swallowed error all produce zero targets — and zero targets read exactly like a
  clean tree.
- **`verify-checksums.sh` pointed at a path that no longer exists**: its error message told the
  reader to run `docs/verify-checksums.sh --update`, moved to `checks/` some time ago. Following the
  instruction failed.

### Changed
- **The list of checks, their perimeter, their rhythm and their gate moved from `METHODE.md` to
  [`repo-controls.md`](docs/repo-controls.md)** — the document the standard names as the owner of
  the control matrix. `METHODE.md` keeps what is a question of *writing*: the discriminator that
  decides a perimeter *(a rule of method follows the method everywhere; a rule of published style
  stops where publication stops)*. **What a commit costs is published with it**, by what it touches
  rather than per check — the same `--commit` spans 0,8 s to 2,6 s, and a duration without its case
  says nothing.

### Added
- **A check for the invariants whose breakage is silent** *(`checks/verify-do-not-break.sh`)*: the
  skill reached through a symlink rather than a drifting copy, the three files kept tracked against
  the neighbouring template `.gitignore`, and the absolute paths the assistant's own instructions
  read at every session start. Nothing reported any of the three, in either direction — and none of
  them raises an error when it breaks: the skill just vanishes from the list, a session quietly
  loses the documents it reasons from, a generated project quietly ships without three files.

- **A check that the checks are wired as declared** *(`checks/verify-checks-wiring.sh`)*. Three
  hand-written lists name them one by one — the CI steps, what `init-project.sh` copies into a
  generated project, and the table in `METHODE.md` — and a check added, renamed or moved has to
  reach all three by hand. Every way of missing one is silent: absent from the CI it passes no
  gate, absent from `init-project.sh` it ships nowhere, absent from the table it is armed and
  undocumented. Auto-detecting the CI list would be wrong, since four checks have no business
  there; that exception was already written down in the table, so the table is now the source and
  the lists are compared against it.

- **A check on what the assistant ASSERTS as a turn ends** *(`checks/verify-turn-claims.sh`, a `Stop`
  hook, advisory)*. Every other check watches files; none watched the claims. Two failures kept
  recurring: a defect named while the turn ends untouched, and a counted total appearing in no tool
  output. Both are counted, never judged — a model reviewing a turn gives a false green often
  enough to matter, and stacking several does not help. **The patterns were tuned against 4463 real
  turns of this project's transcripts**: the obvious wordings fired on ~15 % of turns, which is
  unreadable; these fire on under 1 %.
- **`verify-turn-claims.sh` watches a third failure: a measurement taken and never recorded.** The
  maintainer pointed it out after it happened — every check was timed, the numbers were shown, and
  they landed in no document, dying with the conversation. Measuring is cheap; forgetting to write
  it down is invisible. Sized the same way as the other two, against the same 4500 real turns:
  measurement vocabulary alone fired on 6 % of turns and a table alone on 3.75 %, so the signal
  requires BOTH plus at least three numeric rows — 0.77 %.
- **A guard on the commands this repo forbids** *(`checks/verify-forbidden-command.sh`, a
  `PreToolUse` hook on Bash)*. Three are refused outright because their verdict is a literal string,
  present or absent: `git rm --cached` on a force-added template file, `gh pr merge --admin`, and
  `gh pr checks`. A fourth — opening a pull request — is only WARNED about, since a second one is
  sometimes right and a guard wrong one time in three teaches its own bypass. Heredoc bodies are
  stripped before matching: the very measurements that sized these rules were commands containing
  those strings, and a naive match would have blocked the work that justified it.
- **A check for the same fact stated twice in different words** *(`checks/verify-echo.sh`, advisory)*.
  Verbatim copying was already covered; restatement was not. Sentence embeddings were tried first
  and **rejected on measurement** — a static model flagged 1840 pairs against this check's 45, and
  the ones it alone reported were noise, the shared domain vocabulary drowning the signal. Weighing
  words by rarity is both cheaper and sharper here. It draws a list and blocks nothing.
- **`verify-growth.sh` also watches the comment outgrowing its code.** An absolute ratio would say
  nothing — these scripts sit at 28–56 % comment, deliberately, since a comment carries the WHY.
  What is observable is the DIFFERENCE between the two growth rates: measured across this repo's
  releases it has a median of 0 and a 95th percentile of +6, with a single real outlier at +149.

### Changed
- 🔴 **`verify-narrative.sh` was blind in every generated project that is not shell.** It TRAVELS
  into all of them, and scanned `*.sh *.yml *.yaml` only — so in a Python, TypeScript or Go project
  it read nothing and reported "no dated narrative" over a repository it had never opened. It now
  reads every tracked text file and knows the comment marker per language (`#`, `//`, `--`, `;`),
  and no longer anchors to the start of a line, so a trailing comment carrying a date is caught too.
- **The comment-drift half of `verify-growth.sh` became its own check** *(`verify-comment-drift.sh`)*.
  Two targets, two rhythms, two conditions: pairing them under one gate blinded the script half on
  a commit touching only scripts, within an hour of being written. It is language-aware for the same
  reason as above, and NAMES the extensions it found no marker for rather than skipping them quietly.
- **`verify-no-secret-tracked.sh` becomes `verify-secret-blindspots.sh`**, and covers the second
  place a secret hides from gitleaks: **the remote URL**. `.git/config` is never tracked, so
  gitleaks reads it neither on staged files nor over the full history — a
  `https://<token>@github.com/…` remote therefore sits in plain text where nothing in the
  repository looks, and survives every clone of the working copy. The credential helper is checked
  with it: it must name a variable, never carry a literal. The offending value is never printed —
  reporting a leak by repeating it moves it into a terminal, a log and a CI transcript.

### Fixed
- **The concision check was blind where it mattered most** *(`checks/verify-growth.sh`)*. Concision
  is a rule of method, so it follows the method into the neighbouring workspace — where the very
  document the method names as the one that must shrink lives. It now reads both repositories,
  against the release timestamp rather than a tag the workspace does not carry, and compares
  **bytes as well as lines**: the curated documents run from 57 to 175 bytes per line, so one
  written a sentence per line can swell by a quarter in bytes while its line count goes *down*.

## [1.2.0] - 2026-08-04

### Added

- **Every generated `AGENTS.md` now carries the two structural exceptions to "a missing workflow is
  not a green".** What is *expected* depends on the **event** and on the **base**, not on the
  repository: `Publish image` listens on `push: tags`, so it is absent from a push to `main` by
  design; and CodeQL's *default setup* never runs on a pull request targeting `develop`. Both
  absences used to read as a failed dispatch, and the documented cure for that is a close/reopen —
  re-firing a CI that never had to run. The rule shipped without its exceptions, so every generated
  project was taught to misread its own pipeline.

- **`verify-travel.sh` now runs in the CI.** It was delivered as a check and reachable only through
  a manual `./check.sh` or the advisory, 24h-throttled `pre-commit` hook — never at the one gate
  that blocks. It is the check whose entire point is seeing what a grep of the tree cannot, so the
  gap mattered: it runs in the job that already generates projects, gated to one matrix shard.

- **`verify-links.sh` — a relative link that resolves nowhere, in BOTH repos.** A dead link is
  invisible: nothing renders an error, the reader simply lands nowhere and stops following
  pointers. This repo runs on pointers — a fact lives in one place and everywhere else there is a
  link — so a broken one silently turns *one source* back into *none*. It found three on its first
  run, two of them real breakages created hours earlier while archiving.
- **`verify-no-secret-tracked.sh` — a file NAMED like a secret, tracked, in BOTH repos.** gitleaks
  cannot see this by design: it looks for secret-*shaped strings*, never for a file *called* `.env`
  or `secrets.md`. An empty one passes it, gets committed, and is filled in at the next commit — the
  leak then lands on a path nobody watches any more. `templates/` is exempt: those are the models
  copied into every project, tracked on purpose.
- **`verify-workspace.sh` — the neighbouring `workspace/`, which nothing else can see.** It has no
  remote *on purpose* — that is what lets `repo/` be public — and the same property makes it
  invisible: no diff against a remote, no CI, and `check.sh` runs inside `repo/` without looking
  beside it. Checks that it is a git repository, has **no remote**, tracks nothing secret-named, and
  holds a single tracking document.
- **`verify-growth.sh` — curated documents that only ever grow.** Advisory. An absolute size would
  be arbitrary, so the yardstick is the project's own history: growth since the last **release**.
  What it makes impossible is growing without noticing.
- **`verify-narrative.sh` — dated narrative in a code comment, which `METHODE.md` forbids.** The
  code says what it does; a comment says only what the code cannot. The story of how a defect was
  found — the date, the incident, the evidence — belongs to the archive.
  🔴 **The rule was recorded as "already respected, nothing to build"** — a verdict taken on a
  snapshot right after a manual review pass, so it measured a rule *freshly tidied*, not a rule
  *kept*. Three violations appeared within hours, in the very scripts written to enforce other
  rules. The discriminator comes from the one conforming case rather than from theory: **a date is
  allowed only on a line that points into `archives/`**.
- **`verify-memories.sh` — the index and the links of the persistent memories.** Memories are the
  sixth place a fact can live and the **only one with no Git structure**: no diff shows them, no CI
  sees them, so they rot unnoticed. A memory missing from `MEMORY.md` is **never recalled** — it
  exists and does nothing — and a broken `[[link]]` is reported by nothing at all. Run by
  `check.sh`, silent where a project has no memories, and **local-only by nature**: they live
  outside the repo, so the CI has nothing to look at, which is not a gap.
- **`verify-delegation.sh` — the three delegation instructions, checked BEFORE the subagent starts.**
  The first check in this repo that runs *a priori*: a `PreToolUse` hook that refuses a subagent
  launch when the prompt omits *"does not re-delegate"* or *"does not call the advisor"*, or when
  the model is not a cheaper one. All three are **opt-ins** — left unwritten, the default does the
  opposite of all three, silently, which is why discipline alone never held.
  It blocks rather than warns because nothing here is a judgement: `model` is a field, the other
  two are strings present or absent. Trigger deliberately **narrow** — anything that is not a
  subagent launch exits immediately, since a guard that fires everywhere earns overrides until
  nobody reads it. The hook registration lives in the local settings, never versioned.
- **`verify-travel.sh` — a path that resolves here but dies where the file LANDS.** Several files
  travel into every generated project; a path written in one of them is read by whoever has *that*
  copy, in a project holding neither `docs/` nor `templates/`. A grep of the tree cannot see it: it
  proves no file *names* a deleted doc, and stays blind to a path that remains written and resolves
  nowhere. That blindness cost two fixes. The script generates a throwaway project (~1s, run by
  `check.sh`) and reads the paths from there. It reports only a **differential** — resolves in the
  template *and* fails in the generated project — so generic patterns, naming examples and URLs
  never show up. To declare a path deliberately absent, test it: `[ -f x ]`.
- **Technical-token coverage in `docs/verify-checksums.sh`.** A checksum proves an `.html` was
  *touched* after its `.md` moved, nothing more — one assembly passed it green with 29 % of the
  arriving facts missing. It now also lists the `.md`'s backticked tokens absent from the page.
  **Advisory, never blocking**: a styled page renders placeholders its own way, and a guard that
  cries on every run is a guard nobody reads.

### Changed

- **The sub-checks moved to `checks/`; the root keeps the four commands.** Two natures were mixed
  at the root: what the maintainer *runs* (`init-project.sh`, `configure-repo.sh`, `check.sh`,
  `open-pr.sh`) and what `check.sh` *calls*. `verify-checksums.sh` already sat apart in `docs/`
  while its siblings cluttered the root — one nature, two treatments.
- **The checks are now triggered by the CI, where they block.** Several were reachable only through
  a manual `./check.sh` — a guard built to replace manual passes, triggered only by a manual pass.
  The `pre-commit` hook replays `check.sh` **advisory** and throttled to 24 h, so it never was the
  net; the pull request is.
- **Two more checks now travel into generated projects** — `verify-narrative.sh` and
  `verify-memories.sh`, alongside `check.sh`, `open-pr.sh` and `verify-tone.sh`. `METHODE` holds
  for every project this repo generates: their code carries comments, and **every** project has
  memories, under a path derived from its own location. Memories being the only place with no Git
  structure, nothing else would ever report an unindexed one there.
- **The CI now AUTO-DETECTS which scripts to shellcheck**, instead of listing them by hand. The
  list had already fallen behind by one script, while `check.sh` had always found them with a
  `find` — so a new script was linted locally and not in the CI, breaking `local == github`
  silently. A forgotten target is a hole nothing reports.
- **The `pre-commit` hook now runs the checks at EVERY commit, and blocks.** It used to replay
  `check.sh` once per 24 h and only speak — so a day of active development was a day with no net
  but the pull request, and drift that is merely printed is drift that gets scrolled past.
  What reads the TREE now runs at every commit, since that is the only moment the tree moves
  *(about a second)*; what reads an external base — the OSV database, the semgrep packs, the pushed
  history — cannot answer differently between two commits at constant tool versions, so it runs
  every 6 h *(`CHECK_MAX_AGE_HOURS`)*. `git commit --no-verify` remains the deliberate way through.
- **`./check.sh --commit`** runs that first lot alone. The checks that read the tree still read
  **all** of it — a check narrowed to the diff is blind by construction, since deleting a file
  breaks a link in another one that no diff mentions. What the changed files decide is whether a
  check *runs*: `shellcheck` when a `.sh` moves, `actionlint` and `zizmor` when a workflow moves,
  the Renovate validator when a config moves, `verify-travel.sh` when a file that travels moves.
  `gitleaks` narrows to what is not pushed yet — a scope whose cost stays flat as the repo grows.
- **`check.sh` runs in about half the time** *(6,25 s → 3,43 s here; 2,08 s for `--commit`)*, which
  is what makes it affordable to run often rather than once a day. Most of it was never a check:
  asking each Python tool for its version booted an interpreter to print a string, 1.5 s of every
  run, where pip already named the directory it installed. `verify-growth.sh` now reads the
  release's line counts in one `git` call instead of one per document, and the Renovate configs are
  validated in a single `npx` call instead of one per file.
- **`configure-repo.sh` asks GitHub four fewer times.** The repository's visibility, the presence of
  `develop`, the presence of `docker-publish.yml` and each branch's classic protection were each
  queried twice — none of them can change while the script runs, and the answer was already held in
  a variable. Fewer round-trips is fewer chances for a transient failure mid-configuration.
- **The checks under `checks/` all run at once** *(0,90 s → 0,22 s)*, and under the external tools
  rather than after them. They read the tree and write nothing, so their sum becomes their slowest.
  **The report is unchanged**: each output is captured and replayed by the block that owns it, in
  the same order as before — verified by diffing the whole output against the sequential run.
  A check whose output is missing is an error, never a pass.
- **A venv left behind by a moved project directory now rebuilds itself.** Moving the directory
  leaves every absolute shebang under `.ci-tools/venv/` pointing nowhere, `pip` included — so
  nothing could repair it in place, and the cure was knowing to run `rm -rf .ci-tools/venv` by hand.

### Fixed

- **🔴 The three checks shipped into every generated project were never run there.**
  `init-project.sh` copied `verify-tone.sh`, `verify-narrative.sh` and `verify-memories.sh` to the
  project's **root**, while the `check.sh` travelling beside them — the same file, unmodified —
  looks for them under `checks/`. All three were present, executable, committed, and dead: the
  second-person rule, the dated-narrative rule and the memories guard reported nothing, in every
  project this repo has generated. They now land in `checks/`, where they live here.
  *(A leftover: those copies were written when this repo still kept its checks at the root. Moving
  them into `checks/` was never carried over into what the repo generates.)*
  ⚠️ **`verify-travel.sh` structurally cannot catch this one**: it honours a path guarded by an
  existence test — `[ -x checks/verify-tone.sh ]` reads as "deliberately absent here". Found by
  generating a project and running its `check.sh`, which is the only thing that shows it.

- **The RUNBOOK taught a release order that cannot be merged.** §3 said to seal the `CHANGELOG`
  first, then tag. `verify-version.sh` compares the newest **versioned** heading to the newest
  **tag**, so sealing first makes the sealing pull request itself red — and a red PR does not merge.
  The tag comes first, the sealing second. *(Verified against `v1.1.0`: its tagged commit still
  carried `## [1.0.0]` as newest heading. At `v1.0.0` the error could not show — no tag existed yet,
  so the guard was a silent no-op.)*

- **Two checks in `configure-repo.sh` could fail without saying so.** The community-profile check —
  the one that exists so *"a missing item cannot stay invisible"* — had no branch for its own read
  failing: the script went straight to `✓ server settings applied`, attesting a completeness it had
  never verified. And the Pages homepage step ended on a `case` with no default, so an unreadable
  Pages URL left the homepage unset without a ✓ or a ⚠. Both now speak.

- **`check.sh` did not validate the Renovate configs at the pinned version.** The version was read
  up to the first dot, which turns `renovate@43.288.0` into `renovate@43` — a RANGE. `npx` then
  resolved whatever `43.x` npm serves that day, so the local run stopped executing what the CI
  executes, which is the single guarantee this script exists to give.

- **The CI-verification command existed in two forms, one degraded.** `AGENTS.md` carried
  `gh run list --commit "$sha" --json workflowName,status,conclusion`; the RUNBOOK, `repo-controls.md`
  and **both templates** had lost the `--json` filter — so every generated project was teaching the
  form that cannot be read workflow by workflow, which is exactly what the rule demands. Not a
  textual duplication: the same instruction, written two ways.

- **The `new-project` skill read its own documents from the wrong place once installed as a plugin.**
  It stated they sat *"two levels above it"*, which held only because it is reached through a symlink
  into the template clone. Packaged as a plugin, every `docs/…` path resolved against **the session's
  working directory** — the project being created — so the runbook and the standard were read from
  there, or not at all, with no error worth noticing.
  A `Step 0` now builds the template root from the **absolute skill directory the runtime states at
  load time**, and verifies `init-project.sh` resolves before anything else runs.
  🔴 **Measured on a real plugin load**, symlink removed to isolate the source: `../../docs/…` fails,
  a bare `docs/…` resolves only when the working directory *is* the template, and
  `${CLAUDE_PLUGIN_ROOT}` is empty — the runtime substitutes it in configuration *(hooks, MCP,
  monitors)*, never in a skill's text.

### Added

- **A minimal `.claude-plugin/plugin.json`**, so the repo can be loaded as a Claude Code plugin.
  Nothing is published yet: it exists to make the packaging testable rather than assumed.

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
