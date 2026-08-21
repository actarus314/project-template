# Changelog

All notable changes to this project are documented here — what it changes for whoever generates a project with `init-project.sh`, configures one with `configure-repo.sh`, or follows the standard and the RUNBOOK.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Each version links to its GitHub Release, which carries the auto-generated list of merged pull requests; each entry links the pull request that delivered it.

> ⚠️ **This file starts on 2026-07-28.** What came before was not reconstructed — doing so from memory would have produced a plausible but false history.
> For that period, the pull requests are authoritative.

## [Unreleased]

### Added
- **State that a stage's detail file explains rather than records**: a measurement or a proof of execution goes in a file of its own beside it, which becomes the archive where evidence belongs. The rule was the maintainer's, and lived only in an archive.
- **Refuse a plan document kept in the neighbouring workspace**: a plan belongs to the session running it, and kept there it holds an execution state the tracking doc owns. The tasks it carves out rise into the tracking doc instead; an archive is exempt.
- **Validate `renovate.json` against Renovate 44.31.0**, up from 44.14.10: the local check pulls the validator at that version, so a config the current bot would refuse is caught before the bot sees it.
- **Give the tracking doc's FORM its own subject file** (`docs/tracking-doc.md`): thirteen armed rules — the row, the numbered task, the stage folders — lived in no rule document, so a refusal named a rule nobody could read. The role stays `METHODE.md`'s.
- **State in `AGENTS.md` twenty-six rules armed checks enforce**, which lived only in their code: a check could refuse a commit for a rule no document stated, leaving the writer to infer it from the refusal. Every figure stays in the control matrix.
- **State that a living document gives the total, not the split**: announcing a breakdown promises to maintain it, and one went stale in a day while its sum still added up — which is what let two wrong columns stand.
- **Refuse a rule added to a check that already declares one**: each check states how many tags it emits, compared to what its code emits, so a rule cannot arrive armed and nameless. It locks the checks carrying several rules; one carrying a single rule is named by the check itself.
- **Refuse a check that names no rule document, or names its own note**: every check now declares where the rule it enforces is written, beside what it does with a verdict. The declaration is what is checked — whether the text is really on that page is a judgement, and a guard does not judge.
- **Refuse a commit subject out of form in the neighbouring workspace too**, where the rule was declared on both repositories and armed on one: no hook passed the message there, and the check's other entry point anchors on an `origin/main` a repository with no remote never has.
- **Record WHICH rule a check refused on**, where the journal held the control's name alone: one carrying nineteen rules said the same thing whatever bit, so no rule could be shown to have never fired. A single-rule check needs no change — its name is already the tag.

### Changed
- **Bump the pinned CI tooling** — osv-scanner to v2.5.0, Trivy to v0.74.0, semgrep to 1.173.0, with their checksums: the template and every project it generates pin the same versions, and a stale pin scans against a stale database.

## [1.7.0](https://github.com/actarus314/project-template/releases/tag/v1.7.0) - 2026-08-18

### Added
- **Name what an agent's work leaves behind** — a local branch that never had an upstream, and a worktree directory git never registered, which neither the harness nor `git worktree prune` removes. Content on the server, the pass deletes it; found nowhere, it is kept as the only copy. ([#153](https://github.com/actarus314/project-template/pull/153))
- **Refuse a percent glued to its value, and every decimal comma**: a value takes a space before `%`, and digits group by a space, never a comma (SI brochure §5.4.4, NIST §15-16). Neither form was ever French, unlike the comma. ([#157](https://github.com/actarus314/project-template/pull/157))
- **Refuse a French decimal comma in published content**, which carries no accent and which nothing read: 95 of the corpus's decimals were French against 14 English, and the mixture was arriving with new work. A thousands separator stays unjudged, that convention never having been settled. ([#157](https://github.com/actarus314/project-template/pull/157))

### Changed
- **Condition preferring a workflow on DECOMPOSABILITY**, where the delegation rule said "as much as possible": coordinated agents sharing files fall from 68.6 % to 30.0 % at four, and at equal token budget a single agent equals every multi-agent architecture measured. ([#152](https://github.com/actarus314/project-template/pull/152))
- **Have a stage's detail file point at the settled fact or trap its tasks touch**, where both files were read only at the closure: an objection settled a week earlier brought a design down, and was found again only while closing it. ([#150](https://github.com/actarus314/project-template/pull/150))
- **State that a subagent's mandate is given once, in its prompt**, widening one in flight being indistinguishable from a prompt injection: of five agents treated that way, the one that refused and stopped had the right default. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Refuse a task that is out of form in the tracking doc**, where five rules on how a task is written held on discipline alone: it opens on an infinitive verb, carries no link, and stays within the commit-subject limit of 72 characters. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Refuse a count inside an open task**, which goes false the moment the work advances and only ticks when all of it is done: a set that can be treated one at a time gets split, while a threshold keeps its number and a ticked task keeps its count. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Refuse a chantier row that is not four columns**, one missing pipe having been enough to put a task where no rule could reach it — unnumbered, unmeasured, and about to make the next honest commit fail. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Refuse a chantier row pointing nowhere**, a stage folder holding nothing, and one carrying no chantier number: three digits then `--`, so a listing sorts by chantier and an empty folder never reads as one something was lost from. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Refuse a `DETAILS.md` reasoning a task the tracking doc no longer carries**, which is the second backlog the method forbids — and it is the stale one that gets read first. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Refuse a chantier folder with no `DETAILS.md`**, the file that reasons its tasks — named exactly, since a folder already holds several and the presence of any proves nothing. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Refuse a chantier number given twice**, whether the other holder is open or already closed: numbering the archive folders turned the union into a folder listing, where reading closed chantiers out of prose had been tried and dropped. It found two live reuses. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Make the Release note a WRITTEN one**, where it repeated the changelog it links to and ran to 10 606 characters for `v1.6.0`: a short paragraph, the highlights, then two links — the version's entries frozen at the tag, and its commits. ([#144](https://github.com/actarus314/project-template/pull/144))
- **Drop the pull-request checklist**, whose five boxes were ticked by whoever wrote the change and attested to nothing `check.sh` does not block on. ([#140](https://github.com/actarus314/project-template/pull/140))
- **Require an isolated worktree for `workspace/` too**, where the concurrent-work rule covered only `repo/`: the neighbour holds the tracking doc both sessions append to, carries no remote, and so has no server-side net that could ever see the collision. ([#146](https://github.com/actarus314/project-template/pull/146))
- **Refuse a check called outside `check.sh`**, where only that file clears the inherited git environment: called directly, a check reads whatever repository the environment names, and 10 of the 22 then answer about the wrong one — 8 while staying green on a false count. ([#149](https://github.com/actarus314/project-template/pull/149))
- **Warn, at the sealing step, that a branch opened before it lands its entries in the version already published**: the two changelog headings sit one line apart, so a three-way merge reports nothing and delivers them twice. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Seal the version BEFORE tagging it, where the runbook tagged first**: every tag captured a CHANGELOG and a plugin manifest still one version behind, and `main` stayed red a whole pull-request cycle while the plugin announced an update that pulling it would not deliver. ([#148](https://github.com/actarus314/project-template/pull/148))
- **Hand over the rule itself on the session's first action**, instead of ordering a re-read of the documents that carry it — a command now counts as much as an edit tool, and a lifecycle gesture still owes its runbook in full, that one being data no short form replaces. ([#138](https://github.com/actarus314/project-template/pull/138))

### Fixed
- **Stop the closing-pass routing from ordering the pass first**: it said to invoke the skill before answering anything else, but that request arrives at the end of a list, so the pass ran before the message had been read. It names the destination, never the moment. ([#156](https://github.com/actarus314/project-template/pull/156))
- **Show the PAT expiry alert as the template actually prints it**: the doc quoted it in French, the template turned English on 2026-07-31, and a documentation split moved the block on 2026-08-03 without rereading it. ([#157](https://github.com/actarus314/project-template/pull/157))
- **Stop a link from exempting a restatement**: naming the other document left a paragraph alone, since pointing at a fact is what the method prescribes — but a pointer replaces that fact, it does not accompany it. Seven passages pointed AND restated, one writing a closed list out in full twice. ([#151](https://github.com/actarus314/project-template/pull/151))
- **Stop the growth guard from punishing the smallest document**: 25 % of a 3.6 KB note is a paragraph and a half, against fifteen for a 30 KB one. A 1 500-character floor suspends the ratio below it, and the percentage tightens to 15 %, which holds the big files alone. ([#151](https://github.com/actarus314/project-template/pull/151))
- **Keep comparing every paragraph at every commit, four times faster**: the same-fact check reached its pairs one by one, for 2.2 s of the gate. An inverted index skips those sharing no word — same result, 0.5 s — where narrowing it to touched files would have moved cover to the pull request. ([#151](https://github.com/actarus314/project-template/pull/151))
- **Stop a restatement from buying its exemption by naming a file KIND**: with 26 files called `DETAILS.md`, citing that name exempted 6 766 pairs and a planted restatement went unreported. A shared name carries its folder now; headers, which a convention makes identical, are exempted instead. ([#151](https://github.com/actarus314/project-template/pull/151))
- **Stop a commit from being refused over what another session is typing**: the same-fact check weighed every word against the working tree, so 42 % more corpus moved a score by 0.078 and a pair between two untouched files turned red. The weights come from HEAD now; what is judged stays the tree. ([#151](https://github.com/actarus314/project-template/pull/151))
- **Stop a quoted rule from reading as open work in `workspace/`**: a leftover is recognised by the mark the tracking doc gives a task, never by a turn of phrase — which was met inside a quotation as readily as inside an instruction, and blocked three commits in one day. ([#150](https://github.com/actarus314/project-template/pull/150))
- **Stop the runbook from prescribing a Release note that publishes empty**, its command omitting the written text on stdin while it and the method still described the generated note they no longer produce. ([#145](https://github.com/actarus314/project-template/pull/145))
- **Stop a git hook's inherited `GIT_DIR` from capturing the generator and the door**: absolute inside a worktree, it outlived every `cd`, wrote two commits onto the caller's branch, flipped its `core.bare`, and had a generated project's checks judge the wrong tree. ([#139](https://github.com/actarus314/project-template/pull/139))
- **Stop an inherited `GIT_INDEX_FILE` from having the checks report on the wrong repository**: absolute as soon as a commit is partial, `git commit -a` being enough and no worktree needed, it survived `git -C` — and 11 of the 22 house checks read this index while judging the neighbour. ([#147](https://github.com/actarus314/project-template/pull/147))
- **Let the closing-pass sequencer see the backlog it counts**, where its row pattern demanded a shape the tracking doc has never had. ([#137](https://github.com/actarus314/project-template/pull/137))

## [1.6.0](https://github.com/actarus314/project-template/releases/tag/v1.6.0) - 2026-08-14

### Changed
- **Bump `renovate` 44.13.1 → 44.14.10**, the validator every `renovate.json` is read by — the CI pin here, and the fallback inside `check.sh`, which travels: a project generated from now on validates its own config against the newer schema. ([#128](https://github.com/actarus314/project-template/pull/128))
- **Give the update policy a single owner**, where it was written almost word for word in three documents with no cross-reference.
  The runbook and the controls document now point at it instead of restating it. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Give the green-CI reading a single owner too**, the runbook keeping the gesture and the agent file what counts as green. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Separate the trap of a gesture from the trap that belongs to none**, the first staying with its step in the runbook.
  The method handed pitfalls to both roles, so the same trap was written twice with nothing arbitrating. ([#129](https://github.com/actarus314/project-template/pull/129))
- **State the ghcr default in one place**, the runbook keeping the gesture and pointing at the reason. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Ship the code of conduct with the private reporting channel** a solo-maintained project needs, where the template still sent every report through the maintainer. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Say in the changelog template that an entry is capped at 300 characters**, which the check that travels with it already refused. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Declare that the PAT table exists in three places on purpose**, the third being the copy a generated project holds. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Give concision a test that decides**: remove the word, the sentence, the line, and keep the removal if nothing breaks.
  The rule asked for concision without saying how to settle a case, so every trim was an argument. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Split four comment blocks from the notes that repeated them**, the comment keeping the bare constraint and the note what it took to get there.
  The closest pair said the same thing twice at 0.88 similarity; the highest left is 0.49. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Say beside each adjustable threshold why it can be moved**, where eight of the thirteen stood bare.
  An exception with no reason on the spot reads as an oversight, and gets widened or deleted at random. ([#129](https://github.com/actarus314/project-template/pull/129))
- **State the search-before-building rule in the method**, where it lived in a machine-local file that no clone and no generated project ever read.
  It now covers the whole undertaking, not just the choice of a tracking tool, and says to read the inventory rather than a remembered count. ([#130](https://github.com/actarus314/project-template/pull/130))
- **Give the work in flight a place of its own**, one folder per open stage, named like the archive it becomes.
  Closing a stage turns into moving that folder, instead of picking files out of a root. ([#130](https://github.com/actarus314/project-template/pull/130))
- **Stop the project skill from naming a discovery tool**, which was a broken symlink on the machine that prescribed it.
  A rule that names its instrument dies with it; the gesture stays, the tool no longer does. ([#130](https://github.com/actarus314/project-template/pull/130))
- **Stop a renamed archive folder from reading as a stage that just closed**, which asked the tracking doc to shrink for work closed a month earlier.
  What git reports as a rename leaves the set; an archive folder that is genuinely new still triggers the verdict. ([#134](https://github.com/actarus314/project-template/pull/134))

### Added
- **Gate the workspace's own commits**, which the checks reading it never covered: they ran only when `repo/` was committed too, and nothing scanned its staged content for secrets.
  A generated project is armed from its first commit; one armed at nothing is warned about, never blocked. ([#133](https://github.com/actarus314/project-template/pull/133))
- **Fire a project's version check when a session opens**, from the plugin's own hook rather than from anything the project has to install.
  A project carrying no such check triggers nothing, and says nothing. ([#132](https://github.com/actarus314/project-template/pull/132))
- **Tell whoever opens a session in a generated project that its template has moved on**, naming what was read and linking the release that changed it.
  The project itself receives nothing: without the plugin, it knows nothing. The comparison is against the latest release, never against `main`. ([#132](https://github.com/actarus314/project-template/pull/132))
- **Warn at session start when the plugin itself is behind**, from its own repository, so the line shows in any folder and not only in a generated project.
  Claude Code does not auto-update a third-party marketplace. A manifest declaring no repository is said so, never guessed at. ([#132](https://github.com/actarus314/project-template/pull/132))
- **Show in one place which generated projects run behind the template**, with `./fleet.sh`, reading the projects the harness has already seen.
  A moved project leaves a dead entry, counted under the table; one never opened with Claude Code is invisible, and cannot be counted at all. ([#132](https://github.com/actarus314/project-template/pull/132))
- **State that reading a mechanism means reading its file whole**, where an exact citation was passing for a verified argument.
  Content needs the passage; behaviour needs the whole file, and past 25 000 tokens a read is silently truncated. ([#131](https://github.com/actarus314/project-template/pull/131))
- **Declare what a `SKILL.md` owes**, which no document stated while the runbook depended on one. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Allow the README to restate a description, never a rule**, the line that was practised without being written.
  A visitor never clones, so sending them elsewhere to learn what a folder holds points at a file they will not open. ([#129](https://github.com/actarus314/project-template/pull/129))

- **Refuse a skill front matter whose `description` is folded onto the `name` line**, a break that raises no error. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Refuse the loss of the one address a generated project has** for the documents it never receives.
  Its notes name them, which is allowed; only the charter says where to read them, so that line going missing silences every pointer at once. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Ship `check.sh` and `open-pr.sh` with their own notes**, which stayed behind while both scripts travelled. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Tell a generated project where the documents it does not hold can be read**, from the notes charter, at a link pinned to the version it was born from.
  Those notes name the method and the controls document, which never travel. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Refuse a pointer that credits a document with a formula it does not carry.**
  A link is checked, an attribution is not, and one stayed false while every link around it resolved.
  Only a quoted formula counts; a paraphrase would need a judgement. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Refuse an open action sitting outside the tracking doc**, in a file pledging to hold none or in an archive still being written.
  Splitting that doc into neighbours recreates the separate backlog the method forbids.
  Only a leftover declaring itself matches. ([#129](https://github.com/actarus314/project-template/pull/129))

### Fixed
- **Stop asking for the runbook when a command merely NAMES a lifecycle script**, a `grep` or a `wc` paying the same price as a real invocation — the gesture is now read in command position, wrappers peeled. ([#135](https://github.com/actarus314/project-template/pull/135))
- **Say when a hook has no interpreter instead of measuring nothing**: two of them recorded no line at all without `python3`, leaving a journal that looked healthy. ([#135](https://github.com/actarus314/project-template/pull/135))
- **Refuse to guess the event on an unreadable payload**, where the housekeeping hook fell back to the one branch that can block — including during a forced compaction it must never block. ([#135](https://github.com/actarus314/project-template/pull/135))
- **Require the `# blocking:` header from every check, hooks included**, which the cross-check exempted in bulk: two shipped without one. ([#135](https://github.com/actarus314/project-template/pull/135))
- **Count an instruction to open a pull request when a word separates the verb from its target** — `ouvre et merge les pr` was missed, and the opening it authorised filed as unauthorised. The pattern now turns away bans and generic targets, and ignores harness-injected text. ([#135](https://github.com/actarus314/project-template/pull/135))
- **Stop counting a refused opening and its retry as two**, where the first consumed the order and the second was filed as unauthorised. An order also no longer outlives the session it was given in. ([#135](https://github.com/actarus314/project-template/pull/135))
- **Keep two openings towards different repositories apart**, where the retry fingerprint dropped the wrappers and with them the target, so the second one left the count entirely. ([#135](https://github.com/actarus314/project-template/pull/135))
- **Stop a pinned tool that never arrived from reading as a check that found something**: it exits 3 now, judged on the state on disk.
  `repo/` blocks on a 3; the workspace gate lets the note through, offline, naming what did not run. ([#133](https://github.com/actarus314/project-template/pull/133))
- **Make both skills fire on the phrases they were written for**, where their `description` sat folded onto the `name` line.
  YAML read the pair as one key, so the field the assistant consults before invoking a skill did not exist — the skill loaded and listed, and never triggered. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Stop reading a YAML front matter as prose**, where the sentence-per-line check saw its two keys as one sentence cut in half. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Stop sending a generated project's secrets file to a document it never receives**, named there three times.
  The permission matrix is reached at a link pinned to the version the project was born from. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Repair the sentence explaining why a generated `CLAUDE.md` is versioned**, which stated the opposite of its own reason. ([#129](https://github.com/actarus314/project-template/pull/129))
- **Stop reporting a stage that did prune the tracking doc, once the next stage reopens work.**
  The comparison now asks whether the hot side ever dropped below its pre-closure size, instead of weighing it today.
  It still refuses a closure that never pruned. ([#129](https://github.com/actarus314/project-template/pull/129))
- **See an opening spread over several lines, the shape most commands take.**
  A newline ends a command, and the tokeniser swallowed it as whitespace.
  Replayed against the pull requests the forge recorded, the instrument saw 8 openings of 13; it now sees 12. ([#129](https://github.com/actarus314/project-template/pull/129))
- **See the work in flight once it sits in a subfolder.**
  Reading the workspace root alone, the closure check found nothing under a folder and announced that nothing was left — it failed by passing. ([#130](https://github.com/actarus314/project-template/pull/130))

## [1.5.0](https://github.com/actarus314/project-template/releases/tag/v1.5.0) - 2026-08-08

### Added
- **Ask a closing stage whether it re-read the settled facts and the traps kept beside the tracking doc.**
  Only where those files exist, only over the interval they actually spanned, and a file younger than it is named in the verdict rather than silently skipped. ([#125](https://github.com/actarus314/project-template/pull/125))

- **Refuse a commit subject past 72 characters, uncapitalised, ending on a full stop, or opening on an article.**
  A `commit-msg` hook and a branch-wide check share one file, so the local rule and the CI's cannot diverge.
  Bots and git's own subjects are exempt. ([#124](https://github.com/actarus314/project-template/pull/124))
- **Refuse a pull-request title or body out of form, before anything is pushed.**
  The merge method decides whether the title or the branch's subjects survive, so both are held to one form.
  The owed body sections are read from the repository's own template. ([#124](https://github.com/actarus314/project-template/pull/124))
- **Generate a Release note from the `CHANGELOG` instead of writing one for the occasion.**
  `release-notes.sh` prints the version's block, then the auto-generated pull-request list, and fails rather than print half a note.
  It reads `Unreleased` while the version is not sealed yet. ([#124](https://github.com/actarus314/project-template/pull/124))
- **Delete a dead local branch only once the remote reads `gone` and its pull request is `MERGED`.**
  `gone` alone also matches a branch removed by hand on the forge, and a local branch is the only copy left.
  It prints every branch it examined and the verdict that decided it. ([#121](https://github.com/actarus314/project-template/pull/121))
- **Refuse to proceed until the transcript shows every rule document was read, not just summarized.**
  Compaction can make an old conclusion feel already read, so the check re-arms per document.
  A read using `offset`/`limit` does not count.
  A project with no such documents is unaffected. ([#119](https://github.com/actarus314/project-template/pull/119))
- **Stop quoted text from being read as a command that was actually run.**
  Neither of the check's two text splits respected quotes, so a false match consumed the instruction token and filed the next real opening as unauthorized.
  Both now use `shlex`. ([#119](https://github.com/actarus314/project-template/pull/119))
- **Refuse a sentence hard-wrapped across two lines in a versioned `.md`.**
  Structure — headings, tables, bullets, quote markers, HTML comments and fenced code, including either nested inside a blockquote — is left alone; only a genuinely cut sentence gets joined. ([#123](https://github.com/actarus314/project-template/pull/123))

### Changed
- **Ship a tracking-doc template that says when to split off what is settled and what bites.**
  One file while it still answers "what do I do next" at a glance; past that, both move out beside it, and nothing outside the doc may call for a gesture. ([#125](https://github.com/actarus314/project-template/pull/125))

- **Verify that closing a stage shrank the live tracking doc, instead of checking it against a date.**
  An archive is a directory being created, never a file named inside it; a closure not yet committed is read too.
  The `repo/` half is unchanged and now documented as weak. ([#122](https://github.com/actarus314/project-template/pull/122))
- **Speed up the commit gate from 9.1 s to 3.95 s, with identical verdicts.**
  The two checks that generate a whole project to test it now run inside the same parallel batch as the others, instead of afterward; each generates its project in its own temporary directory, so nothing conflicts. ([#120](https://github.com/actarus314/project-template/pull/120))
- **Require the runbook to be read right before the action it governs, not earlier in the session.**
  An earlier read gives the same false confidence as a current one, without guaranteeing the gesture is still right.
  The method and the standard stay owed on every write. ([#120](https://github.com/actarus314/project-template/pull/120))

### Fixed
- **Count a backlog item numbered `13.1` in the closing pass's coverage.**
  The sequencer matched whole numbers only, so a decimal item was invisible while the pass still reported covering the whole document. ([#125](https://github.com/actarus314/project-template/pull/125))

- **Correct the note claiming the closing pass's scratch files vanish when the tracking doc is written.**
  They go at the next `Stop`, and the condition is the doc's commit — so a look taken right after a write finds them still there and reads a leak that is not one. ([#125](https://github.com/actarus314/project-template/pull/125))

- **Stop the growth check from reporting a correct closure as a failure to prune.**
  It read the tracking doc at the commit that created the archive, so a pruning done in the next commit was invisible.
  The comparison now ends at `HEAD`, covering a closure spread over several commits. ([#125](https://github.com/actarus314/project-template/pull/125))

- **Correct the control table, which still published the changelog cap as 750 characters drawn from the corpus.**
  The cap is 300, taken from Common Changelog, and the whole entry form the check now refuses is listed there. ([#124](https://github.com/actarus314/project-template/pull/124))
- **Give the changelog a stated, enforced form.**
  One section of each type per version, a Release link on every heading, and an entry that opens on the effect, holds 300 characters and ends with the pull request that delivered it.
  Every published version was brought into line. ([#123](https://github.com/actarus314/project-template/pull/123))
- **Delete the closing pass's scratch enumeration file, not only its in-progress flag, once the pass hits its cycle limit.**
  Left behind, the next pass read the old enumeration as its own already-done coverage. ([#123](https://github.com/actarus314/project-template/pull/123))
- **Recognise "fin de travail" as another way of asking for the closing pass, alongside "fin de chantier".**
  The same request, one word apart, used to reach no skill at all. ([#123](https://github.com/actarus314/project-template/pull/123))
- **Stop three blocking checks from printing "(advisory)" above their own output while still refusing the commit.**
  Their header and the control table already said `blocking: yes`; only the wording a reader sees was wrong.
  Only the genuinely advisory check keeps that word now. ([#122](https://github.com/actarus314/project-template/pull/122))
- **Stop the end-of-turn check from misreading a French-style thousands separator as the end of the number.**
  Written `5 300`, it compared only `300` against the turn's output, so a number above 999 failed to match and read as unbacked.
  Separators are stripped before the comparison now. ([#120](https://github.com/actarus314/project-template/pull/120))
- **Stop a second request for the closing pass from restarting one already half-done.**
  The word-routing branch used to arm a new pass without checking whether one was already armed.
  It now points at the pass under way and leaves it alone. ([#120](https://github.com/actarus314/project-template/pull/120))
- **Cover local branches whose remote is gone, not only the ones never pushed.**
  `git branch --merged main` cannot find them: this repository merges by squash, so a merged branch is never an ancestor of `main`.
  The inventory now runs `git fetch --prune` then greps for `: gone]`. ([#120](https://github.com/actarus314/project-template/pull/120))

## [1.4.1](https://github.com/actarus314/project-template/releases/tag/v1.4.1) - 2026-08-07

### Added
- **Record every flag used to generate a project, not only the template version.**
  The options were deduced from the tree, unreliable once a default changes.
  The stamp now lists every flag, negatives included, plus the origin URL.
  An earlier project still carries only the version. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Stop the placeholder scan from flagging its own documentation as a bug.**
  Files that travel with a generated project to document placeholders were flagged as unsubstituted ones.
  The scan now skips anything copied verbatim from the root; the CI's drifted copy now matches it. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Stop misreading a quoted command name as a real opening.**
  The instrument measuring whether a pull request was opened on instruction split on whitespace, so a quoted assignment like `PKG="check.sh ..."` fell apart and counted as an opening.
  It tokenises with `shlex` now, so quotes hold. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Report which documents a growth check could not compare.**
  A document created since the last release has no earlier version to grow against, so it used to pass unnoticed at any size.
  The verdict now names how many are new since the tag, instead of staying silent. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Commit a generated project's `CLAUDE.md`, so a clone is enough to read its rules.**
  It was gitignored, and it is the only file that loads `AGENTS.md`.
  It ships reduced to the `@AGENTS.md` import.
  The runbook's adoption step now covers only a repository with a pre-existing `CLAUDE.md`. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Ship the script and documentation a generated project needs to reconfigure its server settings later.**
  It carries `configure-repo.sh`, a RUNBOOK link pinned to the version it was generated from, and `docs/server-config.md`.
  That guide is now a deliverable to keep current. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Explain, in a generated project, why its checks refuse what they refuse.**
  It shipped 24 controls with no line saying why any exists, so a failing gate read as arbitrary.
  `AGENTS.md` now carries six rules, worded for the project rather than copied from the method document. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Add a check that generates a project and runs its own CI gate on the spot.**
  An existing check only asked whether a path still resolves there; this one asks whether the gate passes — three defects lived in that gap.
  It covers one variant, and prints the command to replay a failure. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Document how to bring a live project forward to a newer template version.**
  The template's diff does not apply cleanly: a project is not a subset of it.
  The runbook says to generate a matching reference project, diff the two trees, and finish when `./check.sh --house` is green. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Refuse a tracked file that names a private project.**
  `gitleaks` matches token shapes; a plain name has none.
  A new check reads a list of private names kept outside this repository, and states which file it read, or none.
  It cannot remove a name already pushed to history. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Version this repository's own `CLAUDE.md`, so a clone is enough to read its rules.**
  It was gitignored, and it is the only file that loads `AGENTS.md`.
  The rule is not only that it is published, but what it may contain: the file carries nothing but the `@AGENTS.md` import. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Add two guards so the `CLAUDE.md` rule does not rely on memory.**
  One fails when a versioned `CLAUDE.md` stops importing `@AGENTS.md`, or gains a machine path.
  The other refuses a `/Users/…` or `/home/…` path anywhere in versioned content. ([#117](https://github.com/actarus314/project-template/pull/117))

### Changed
- **Name the implementation notes among `METHODE.md`'s roles.**
  The table stated where a fact lives — tracking doc, archives, actions, conventions, code, memories — but left out the implementation notes, so nothing said what that level must never contain. ([#117](https://github.com/actarus314/project-template/pull/117))

### Fixed
- **Stop nesting a generated project's ADRs one level too deep.**
  Copying into a destination that already exists nests the copy inside it, and the directory had already been created earlier by the notes that travel beside the checks.
  Affects every project generated since 2026-08-05. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Stop shipping macOS index files in a generated project.**
  Copying from disk rather than from git carried `.DS_Store` along with copied directories.
  The generated `.gitignore` kept them out of any commit, but a project should not be born with someone else's clutter in its tree. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Cover a workflow's own subagent calls in the delegation guard.**
  It hooked only the direct agent tool, so a workflow's own calls went unenforced.
  It now reads the workflow's script and states the count found.
  Invoked by name, a workflow is reported unread, never silently passed. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Recognise ordinary French verb conjugations in the delegation guard.**
  It listed three spellings of one verb and missed the form used, so a normal French prompt matched none and was refused.
  Accents are matched as a character class now.
  The check still only tests for the words' presence. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Stop every project generated since `v1.3.0` from being born with its first pull request blocked, through no fault of its owner.**
  Three defects broke its CI gate: dead links to a missing charter, a check dying on an empty match, and a threshold that failed on a smaller document set. ([#117](https://github.com/actarus314/project-template/pull/117))
- **Make an unreachable warning reachable in two more checks.**
  Each carried a message meant to fire when a pipeline reads nothing, but the script exited before that message could print — the same silent death one sibling check had already met and documented, uncarried to the other two. ([#117](https://github.com/actarus314/project-template/pull/117))

## [1.4.0](https://github.com/actarus314/project-template/releases/tag/v1.4.0) - 2026-08-06

### Added
- **Ask what became of a deleted comment block.**
  When five or more lines of explanation leave a script, the commit message must say they were never worth writing — or they move into the file's note, so a *why* is not lost in passing.
  A `drop:` covers only the files it names. ([#115](https://github.com/actarus314/project-template/pull/115))
- **Measure whether the pull-request rule needs enforcing in code, before enforcing it.**
  Every opening is recorded as made *with* or *without* an instruction, and nothing is ever refused.
  Below 5 % over 20 openings, no gate gets built. ([#114](https://github.com/actarus314/project-template/pull/114))
- **Hold the end of a turn until the closing pass has actually covered the tracking doc**, item by item and section by section.
  A pass can no longer be declared done with half of it skipped; after three send-backs the turn is released and the gap is named. ([#112](https://github.com/actarus314/project-template/pull/112))
- **Refuse a file that is born over-commented**, not only one that drifts there: at most 25 % comment and no block longer than 6 lines, on the files a branch touches.
  A file that never grows used to trigger nothing at all. ([#111](https://github.com/actarus314/project-template/pull/111))
- **Give every script a note of its own**, holding the constraints behind the way it is written — so the *why* has somewhere to go when it leaves the code.
  The notes travel with the checks into a generated project. ([#111](https://github.com/actarus314/project-template/pull/111))
- **Go through the open work line by line when closing a stage.**
  Asked as a single question, a document written the same day answers *yes* at a glance: four finished items sat in the open section for a full day. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Recognise a request for the closing pass in what is typed**, instead of hoping the right skill fires on its own.
  It was measured failing on the maintainer's own words. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Watch every skill's link, not just the first one.**
  The second skill shipped with nothing guarding its link — and an unlinked skill does not fail, it silently disappears from the list. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Refuse finished items left in the open-work section** of the tracking doc.
  ⚠️ It reads a marker, never a state: an item finished and never marked stays invisible to it. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Make every check declare whether it blocks, and confront that claim twice** — against the control table, and against the exit code it really returns.
  Three checks were announcing the opposite of what they did. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Add the closing pass that brings the tracking doc back in line with the work.**
  A guard counts the commits landed since it was last written and asks for the pass past six.
  Code counts, a model writes. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Warn when a finished stage left no archive behind**, or when finished research still sat among the live documents at release time.
  Advisory, and it carries only what the growth check cannot see — two controls answering one question end up disagreeing. ([#109](https://github.com/actarus314/project-template/pull/109))

### Changed
- **Read the whole tracking doc when closing a stage, not only the open-work list.**
  Everything else was left to rot: one reading found a stale entry point, two sections restating the same work, and three false facts. ([#111](https://github.com/actarus314/project-template/pull/111))
- **Frame delegation as a cost, not a prescription.**
  Handing six `git` commands to a subagent costs more than running them; the rule is to delegate as soon as it costs less. ([#111](https://github.com/actarus314/project-template/pull/111))
- **End a turn by blocking rather than remarking** when a claim looks unbacked, so the reason reaches the assistant and gets settled.
  Capped at one relaunch per turn, so a false alarm costs one exchange. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Record whether a check actually caught something, not merely that it ran.**
  *Did it bite* is the question a threshold is set on, and only *did it fire* was being answered. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Keep the record of which checks fire outside the repository**, shared by every generated project, each line naming the project it came from.
  *Is this check firing everywhere, or only here* now has somewhere to be answered. ([#109](https://github.com/actarus314/project-template/pull/109))
- **Write a dependency bump's changelog line on the bot's own branch, before merging.**
  A line added afterwards is a discipline; on the branch, a line that gets dropped turns the check red again. ([#108](https://github.com/actarus314/project-template/pull/108))
- **Bump `trivy` v0.72.0 → v0.73.0** in the image-publishing workflow — it travels, so every project generated with `--artefact` scans its image with the newer one; `renovate` 44.7.0 → 44.13.1. ([#105](https://github.com/actarus314/project-template/pull/105), [#106](https://github.com/actarus314/project-template/pull/106))
- **Bump `zizmor` 1.28.0 → 1.29.0** among the pinned CI tools, so every project generated from now on pins the newer one; `renovate` 43.288.0 → 44.7.0. ([#101](https://github.com/actarus314/project-template/pull/101), [#102](https://github.com/actarus314/project-template/pull/102))

### Removed
- **Drop the "second pull request on the same undertaking" warning.**
  Three forms were tried and each ruled out; it stays a written convention and stops pretending to be a guard. ([#110](https://github.com/actarus314/project-template/pull/110))

### Fixed
- **Correct four statements the documentation made that were no longer true**, each re-measured: a repo called private after it went public, a tool listed at its old path, a gate timed at 2.82 s against 3.65 s, a command missing a precondition. ([#115](https://github.com/actarus314/project-template/pull/115))
- **Document the standalone secret-scanning workflow instead of deleting it.**
  A sweep found it referenced nowhere and read as dead code; it is what an adopted repository uses when its own CI has no scan. ([#115](https://github.com/actarus314/project-template/pull/115))
- **Stop a commented-out line from passing as a wired check.**
  The check that verifies every gating workflow calls the house checks read a workflow's whole text, so a disabled line satisfied it while gating nothing. ([#115](https://github.com/actarus314/project-template/pull/115))
- **Say how many lines the tone check has been told to skip.**
  An exemption marker frees its line anywhere in the tree; 10 lines today.
  A number that grows can be noticed, an unwritten one cannot. ([#115](https://github.com/actarus314/project-template/pull/115))
- **Stop the runbook granting what the conventions withhold.**
  Its release table read as a standing authorisation to open a pull request.
  Both documents now say it happens on the maintainer's instruction. ([#114](https://github.com/actarus314/project-template/pull/114))
- **Fix the closing pass reading a payload field that does not exist, and staying silent about it.**
  A real gap looked exactly like never firing.
  It now reads every text value, and says what it read. ([#113](https://github.com/actarus314/project-template/pull/113))
- **Stop the changelog check refusing the very commit that carried the line it asked for.**
  It read committed history only, while the pre-commit hook runs before the commit exists.
  It now also reads what is staged, and what is neither. ([#112](https://github.com/actarus314/project-template/pull/112))
- **Replace a justification that was false in this repository.**
  The comment-drift check said releases are rare; there had been four tags in five days.
  What holds at any cadence is that a release-anchored reference re-opens already-merged work. ([#112](https://github.com/actarus314/project-template/pull/112))
- **Make the narrative check able to catch a story at all.**
  Its only signal was a date, and every hit pointed into the archives, which the rule exempts — it had never caught anything.
  Recall is traded for precision, deliberately, because this one refuses a commit. ([#111](https://github.com/actarus314/project-template/pull/111))
- **Recognise two more ways of asking for the closing pass.**
  A second miss proved the list was short; three candidates were measured over 1683 real messages before one was kept.
  Asking to SEE the state is still not asking for the pass. ([#111](https://github.com/actarus314/project-template/pull/111))
- **Stop the growth check blocking on a page nobody writes.**
  The controls page is regenerated whole at every run: it grows by recording, and the rule it enforces — a curated document shrinks when a stage closes — has no meaning for it. ([#111](https://github.com/actarus314/project-template/pull/111))
- **Revert the exemption that let a bot's pull request skip the changelog check, one day old.**
  It silenced the control on exactly the changes that reach a user: pinned tools travel into every generated project.
  An automated pull request is now red until the line is added to its branch. ([#107](https://github.com/actarus314/project-template/pull/107))
- **~~Fix every automated pull request being red on a check nothing could satisfy.~~** *(Superseded by the line above — the diagnosis stands.)* A dependency bump touches exactly the paths counted as user-visible, and no bot writes prose. ([#103](https://github.com/actarus314/project-template/pull/103))

## [1.3.0](https://github.com/actarus314/project-template/releases/tag/v1.3.0) - 2026-08-05

### Added
- **Make every tracked executable answer `--version`.**
  Seven did not, so the version check silently skipped them: `verify-tone.sh`, `verify-version.sh` itself, `open-pr.sh`, the git hooks, and `check.sh`.
  Coverage grows from 18 scripts to 25. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Make three more checks publish what they read.**
  The tone check gave a bare tick with no count; the version check named none of the executables it compared; the narrative check claimed both repositories with no count per side.
  All three now say what they saw. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Stop a commented-out mention from satisfying the wiring check.**
  Its read-back test matched a check's name anywhere in `check.sh`'s text, so a check merely named in prose passed with its verdict never actually read.
  Only code lines count now. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Add a check for French left in published content (`verify-language.sh`).**
  The tone check watched for the second person, never the language, so an all-French paragraph passed unnoticed.
  🔴 It signals on the accent only: unaccented French still gets through.
  `repo/` only. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Translate a French block left at the top of the generated README.**
  The new language check caught it on its first run: every generated project was shipping instructions in French. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Close a hole the wiring guard had in itself.**
  A check could be declared, copied and started, yet have no line in `check.sh` reading its result back — its verdict written to a file nobody opened.
  The guard now checks that too, not just whether a check is named. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Add `./check.sh --report`, a control journal for development.**
  It records how long each control costs and whether its gate ever fires.
  🔴 Off by default: nothing is written until `--report --on`, and the record stays local, never repository content. ([#97](https://github.com/actarus314/project-template/pull/97))
- **Make every check travel into a generated project, with a gate waiting there.**
  A project used to receive three of eighteen, with no generated workflow calling any of them.
  `init-project.sh` now copies `checks/` whole, and one line, `./check.sh --house`, runs it all. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Add `./check.sh --house`, running only the house checks.**
  External tools — gitleaks, semgrep, osv-scanner, actionlint, zizmor — stay the CI's own pinned and checksummed steps; replaying them here would just re-download and rerun them for one verdict. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Make the wiring check guard the gate itself.**
  A missing `./check.sh --house` line in any gating workflow — this repository's or any of the three shipped templates — now fails the build.
  It also compares the hooks the table marks `n/a` against the ones actually excluded. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Add a check for invariants that break silently (`verify-do-not-break.sh`).**
  It watches the skill reached through a symlink, three files force-tracked against the template's `.gitignore`, and the absolute paths read at session start.
  None raises an error when broken — each just vanishes. ([#91](https://github.com/actarus314/project-template/pull/91))
- **Add a check that every check is wired where it should be (`verify-checks-wiring.sh`).**
  A check needed hand-updating in three lists — CI steps, what `init-project.sh` copies, and the table in `METHODE.md` — missing one left it ungated, unshipped, or undocumented.
  The table is the source. ([#91](https://github.com/actarus314/project-template/pull/91))
- **Add a check on what the assistant claims as a turn ends (`verify-turn-claims.sh`, advisory).**
  It catches a defect named but never fixed, and a counted total that appears in no tool output.
  Both are counted, never judged by a model — the wording is tuned to fire on under 1 % of turns. ([#91](https://github.com/actarus314/project-template/pull/91))
- **Watch for a third failure: a measurement taken and never written down.**
  A check can be timed and the numbers shown, yet never land in any document.
  The signal fires only when measurement wording appears together with a table of at least three numeric rows. ([#92](https://github.com/actarus314/project-template/pull/92))
- **Add a guard on the commands this repository forbids (a `PreToolUse` hook on Bash).**
  `git rm --cached` on a force-added template file, `gh pr merge --admin`, and `gh pr checks` are refused outright; opening a pull request is only warned about, since it is sometimes the right call. ([#91](https://github.com/actarus314/project-template/pull/91))
- **Add a check for the same fact restated in different words (`verify-echo.sh`, advisory).**
  Verbatim copying was already covered; paraphrase was not.
  It weighs words by rarity rather than comparing sentence embeddings, which proved noisier here.
  It lists candidates and blocks nothing. ([#91](https://github.com/actarus314/project-template/pull/91))
- **Make the growth check also watch the comment outgrowing its code.**
  An absolute ratio says nothing, since these scripts deliberately carry 28–56 % comment; what is watched is the gap between the two growth rates, which normally stays near zero. ([#91](https://github.com/actarus314/project-template/pull/91))

### Changed
- **Make the comment-drift check count in bulk — 1.14 s → 0.53 s.**
  Four per-file forks become three bulk `git grep` calls per marker family.
  ⚠️ Counts used to key off argument order, which broke when a marker family produced several files or none; every count is tagged now. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Re-measure all sixteen control durations, as medians of three standalone runs.**
  Their sum falls from 5.24 s to 3.89 s while gaining a check, and the ranking changes: the echo and growth checks are no longer where the prose said. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Stop duplicating the git hooks under `templates/`.**
  `init-project.sh` now copies `.githooks/` from the root, like `check.sh`, `open-pr.sh` and `checks/`.
  The old duplicate had already drifted: same behaviour, different wording. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Make the growth check read both revisions in four calls total, not two per file.** 0.88 s → 0.17 s.
  🔴 `git cat-file --batch` looked like the fix and was rejected: its stream mixes headers with raw bytes, so a file missing a trailing newline shifts every object after it. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Make the version check ask its scripts in parallel — 0.52 s → 0.27 s.**
  Each answer lands in its own file rather than a shared pipe, since interleaved writes on a shared pipe can attribute one script's version to another. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Stop the echo check flagging the very pointer METHODE prescribes.**
  A paragraph that links to another document necessarily shares its vocabulary; such pointers are now excluded, and the French detector no longer misreads a bilingual document's French half as English. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Make the three advisory checks block instead of warn.**
  A warning nobody must act on is a warning nobody reads.
  The comment-drift check gained a floor in lines beside its percentage gap, and the echo check now excludes `CODE_OF_CONDUCT.md`, third-party text that restates itself by design. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Make the echo check 7× faster — 1.78 s → 0.25 s, same verdict.**
  It used to detect a paragraph's language once per compared pair inside a quadratic loop; now once per paragraph.
  The CI gate's floor drops to 3.05 s. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Correct the control table's durations, off by 1.7× to 4.1×.**
  They were single cold runs on a busy machine.
  They are medians of three now, and the table says so. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Make a hook declare itself with a `# hook: <event>` header line.**
  `check.sh` detects that line instead of naming the three by hand — the last hand-written list left in the runner.
  An unmarked fifth hook would have joined the parallel lot and hung on stdin. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Make every check detect on its own whether its subject exists where it lands.**
  Present, it runs; absent, it says so and returns clean.
  This is what makes travelling into any generated project possible without a hand-picked list of which checks belong. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Replace twelve hand-written CI steps in this repository's own `ci.yml` with one line.**
  That list was one of three that had to be kept in agreement by hand; a check missing from it passed no gate at all. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Stop `CONTRIBUTING.md` and `AGENTS.md` restating each other in generated projects.**
  The branching rules and the merge-verification procedure were written out in both files.
  `AGENTS.md` now keeps them, since it is what an agent reads; `CONTRIBUTING.md` points at it instead. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Move the control matrix — checks, perimeter, rhythm and gate — to [`repo-controls.md`](docs/repo-controls.md).**
  `METHODE.md` keeps only the writing question: whether a rule follows the method everywhere or stops at publication.
  What a commit costs is published by what it touches. ([#93](https://github.com/actarus314/project-template/pull/93))
- **Stop the narrative check being blind in every generated project that is not shell.**
  It scanned `*.sh *.yml *.yaml` only, so a Python, TypeScript or Go project read as clean, unopened.
  It now reads every tracked text file and knows each language's comment marker. ([#91](https://github.com/actarus314/project-template/pull/91))
- **Split the comment-drift half of the growth check into its own check (`verify-comment-drift.sh`).**
  Pairing two different rhythms under one gate blinded the script half on a commit touching only scripts.
  It names any extension with no comment marker, instead of skipping it quietly. ([#91](https://github.com/actarus314/project-template/pull/91))
- **Rename `verify-no-secret-tracked.sh` to `verify-secret-blindspots.sh`, and cover the remote URL.**
  `.git/config` is never tracked, so gitleaks never reads it, and a token in the remote URL sits in plain text through every clone.
  The credential helper must name a variable, never a literal. ([#91](https://github.com/actarus314/project-template/pull/91))

### Fixed
- **Say on the control journal's page whether recording is still running.**
  The state used to print to the terminal only, so the page itself could not distinguish *"recording stopped"* from *"nothing has run"* — two different facts with one indistinguishable line. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Time the seven controls the journal left blank — travelling paths, gitleaks, shellcheck, actionlint, zizmor, osv, renovate.**
  A bare dash read as free rather than unmeasured; they now run on the same clock as the rest. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Make the comment-drift check cross into the neighbouring `workspace/`, like its twin already did.**
  The omission was a plain oversight, since the rule it enforces is a rule of method, not of publication.
  It now publishes how many files it found in each repository. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Make the echo check report every group, even one that came back clean.**
  A clean `workspace/` and a `workspace/` never opened used to print the same silence.
  It now states what each group held, regardless of verdict. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Stop the workspace check being blind to any tracking tool it did not already know by name.**
  A `.linear/` folder read exactly like an empty workspace.
  Every tracked top-level dot-directory is now surfaced by name, minus the editor and forge ones. ([#99](https://github.com/actarus314/project-template/pull/99))
- **Reconcile two sets of durations in `repo-controls.md` that disagreed.**
  The per-control table had been re-measured; the prose two sections below had not, and still announced the echo check at its old 1.36 s and the gate at *"about 3.7 s"* where the table already said 3.05 s. ([#98](https://github.com/actarus314/project-template/pull/98))
- **Document the control journal in `repo-controls.md`, not only in the CHANGELOG.**
  `AGENTS.md` names that file as the sole owner of what controls cost.
  It now also states why the two figure sets differ: the table times a check alone, the journal times it inside the parallel lot. ([#98](https://github.com/actarus314/project-template/pull/98))
- **Make `shellcheck` reach generated projects, not only this repository.**
  It was the only control run here and shipped to nobody, so a shell bug was blocked locally and passed silently everywhere else.
  One step in each of the three workflow templates now covers both. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Make the version check recognise Go and Java, which its own comment claimed it already did.**
  A compiled executable with no source to grep is now named as unexamined, rather than silently passed. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Make the narrative check publish the languages it could not read.**
  It used to swallow them in silence — a `.zig` file with a dated comment came back clean.
  It also now checks a file's shebang when its name carries no extension, which revealed the git hooks had never been scanned. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Stop a broken interpreter printing a clean tick.**
  The narrative check swallowed its own Python errors behind `|| true`, twice, while reading nothing at all. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Stop three checks presuming the shape of the project they landed in.**
  Each read zero files in a Python, TypeScript or Go project.
  Checks now read every tracked executable or `.md` file, whatever the language, instead of a hand-picked list of paths. ([#96](https://github.com/actarus314/project-template/pull/96))
- **Stop one malformed line silently disarming all three turn-claims signals.**
  A single unparseable line anywhere in the transcript used to throw out of the whole read.
  Parsing is now per line, and a partial read stands down only the signal that accuses on an absence. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Make the workspace check count tracking systems, not tracking files.**
  A `.planning/` folder sitting beside `SUIVI.md` — the exact collision METHODE forbids — used to read the same as an empty workspace.
  It now names what it looked for; a project using one system alone stays green. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Stop two checks failing outright in every generated project.**
  The travel check demanded an `init-project.sh` no generated project has, and the do-not-break check demanded generator-only files.
  Each target now detects whether it applies, and names what it did not read. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Stop four checks returning a silent pass where they had read nothing.**
  The memories check, the checksums check, the changelog check, and one target of the do-not-break check each used to print a bare tick — the exact false green this repository otherwise guards against. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Detect the changelog check's perimeter instead of hand-listing it.**
  It named three shipped scripts while ten actually travelled.
  A project holding none of it now says so, instead of reporting a permanent *"nothing visible"*. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Stop the travel check misreporting three checks that guard their targets correctly.**
  It only recognised a shell test on the same line as the path; it now also recognises a negated test, a Python existence test, and a tested parent folder. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Point the three git hooks at a URL instead of a local path in their own messages.**
  The local path resolved nowhere once a project travelled; a URL resolves from anywhere. ([#95](https://github.com/actarus314/project-template/pull/95))
- **Make something watch the three git hooks, which nothing did before.**
  They live outside every repository, in the assistant's local settings, so a dropped entry simply stopped firing with no error.
  The do-not-break check now watches them, deducing which are hooks from the table. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Make `check.sh --commit` see the neighbouring `workspace/`.**
  It is a separate git repository, so a diff run here never reached it — `SUIVI.md` could double in size without waking either the echo or the growth check. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Stop the comment-drift check counting a trailing comment as pure code.**
  That was blind to exactly the shape that lets a comment grow invisibly.
  Such a line now counts as one line of each. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Make two gates read their own input.**
  `zizmor` watched the workflows but not its own config file, and the Renovate validator missed the pinned version that decides its verdict. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Make the changelog check watch a script that changed, not only one added or deleted.**
  The rule it enforces names *"a script's behaviour"* outright; it now watches every script that travels. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Fix the version check comparing 3 scripts out of the 18 that handle `--version`.**
  The list is now derived from the flag actually being handled, and an empty read fails rather than passing. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Widen the secret-blindspots check beyond `.env` and `secrets`.**
  A private key, an `.npmrc`, a `.netrc`, or a service-account file are just as readable, and gitleaks does not know any of them by name. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Stop the links check reading inside fenced code blocks, which its own header promised it skipped.**
  It also resolves anchors now, which is what makes a table of contents safe to write. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Make the travel check generate every project shape, not only one.**
  It used to generate a single `--type node` project, leaving three workflow templates unread.
  It now generates one project per toolchain, read from `init-project.sh`, not listed.
  ⚠️ Real cost: 0.46 s → 1.66 s. ([#94](https://github.com/actarus314/project-template/pull/94))
- **Make the tone check catch the capitalised second person.**
  The capitalised forms at the start of a sentence went untouched while the lowercase ones were caught — and since this check travels, every generated project was equally blind. ([#93](https://github.com/actarus314/project-template/pull/93))
- **Stop `check.sh` dropping the wiring check's own verdict.**
  It ran with the others, but nothing read its result back: a check deleted from `checks/` left the local run green while the CI, reading the same file, went red — breaking the promise that local equals GitHub. ([#93](https://github.com/actarus314/project-template/pull/93))
- **Make a failing check print its own error instead of a bare *"it never ran"*.**
  The subshell capturing each result inherited `set -e`, so a check exiting non-zero died before writing its return code, and its real message was left unread. ([#93](https://github.com/actarus314/project-template/pull/93))
- **Stop a check claiming a perimeter it did not actually read.**
  With the neighbouring `workspace/` renamed away, three checks still announced *"in both repositories"*.
  Each now names what it read and what it did not; zero targets used to read exactly like a clean tree. ([#93](https://github.com/actarus314/project-template/pull/93))
- **Fix the checksums check pointing readers at a path that no longer exists.**
  Its error message told the reader to run a script under `docs/`, moved to `checks/` some time ago; following the instruction failed. ([#93](https://github.com/actarus314/project-template/pull/93))
- **Make the concision check read the neighbouring `workspace/` too.**
  It compares against the release timestamp, since the workspace carries no tag, and checks bytes as well as lines: a document written one sentence per line can swell in bytes while its line count goes down. ([#91](https://github.com/actarus314/project-template/pull/91))

## [1.2.0](https://github.com/actarus314/project-template/releases/tag/v1.2.0) - 2026-08-04

### Added
- **Document the two cases where a missing workflow is normal, not a failed dispatch.**
  `Publish image` is absent from a push to `main` by design, and CodeQL's default setup never runs on a pull request targeting `develop`.
  Both used to be misread and "cured" with a needless close/reopen. ([#87](https://github.com/actarus314/project-template/pull/87))
- **Run the check for paths broken by project generation in the CI, not only locally.**
  It existed only behind a manual `./check.sh` or an advisory, 24-hour-throttled `pre-commit` hook — never at the gate that actually blocks a merge. ([#87](https://github.com/actarus314/project-template/pull/87))
- **Add a check for a relative link that resolves nowhere, across both repositories.**
  A dead link renders no error: the reader lands nowhere and stops following pointers, turning the single source of a fact back into none. ([#86](https://github.com/actarus314/project-template/pull/86))
- **Add a check for a file named like a secret that is tracked, across both repositories.** gitleaks looks for secret-shaped strings, never for a file merely called `.env` or `secrets.md`.
  `templates/` is exempt: those files are the models copied into every project, tracked on purpose. ([#86](https://github.com/actarus314/project-template/pull/86))
- **Add a check for the neighbouring `workspace/` directory, which nothing else can see.**
  It has no remote on purpose, which is also what makes it invisible to any diff or CI.
  The check verifies it stays a git repository with no remote and no secret-named file. ([#86](https://github.com/actarus314/project-template/pull/86))
- **Add an advisory check on curated documents that only ever grow.**
  The yardstick is growth since the project's last release, not an arbitrary size — so a document cannot grow without anyone noticing. ([#86](https://github.com/actarus314/project-template/pull/86))
- **Add a check that refuses dated narrative in a code comment.**
  A comment should say only what the code cannot; the story of how a defect was found belongs in the archive.
  A date is allowed only on a line pointing into `archives/`. ([#85](https://github.com/actarus314/project-template/pull/85))
- **Add a check for the index and links of the persistent memories.**
  Memories are the one place with no git structure: a memory missing from the index is simply never recalled.
  Local-only by nature, and silent on a project with none. ([#84](https://github.com/actarus314/project-template/pull/84))
- **Refuse a subagent launch that omits any of the three delegation instructions.**
  Each is an opt-in: left unwritten, the default silently does the opposite.
  It blocks rather than warns, and exits immediately on anything that is not a subagent launch. ([#84](https://github.com/actarus314/project-template/pull/84))
- **Add a check for a path that resolves here but breaks wherever a travelling file lands.**
  Several files are copied into every generated project; a grep of the tree cannot see a path that resolves in the template and dies in a project with neither `docs/` nor `templates/`. ([#84](https://github.com/actarus314/project-template/pull/84))
- **Catch missing facts in a rendered page, not just a stale checksum.**
  A checksum only proves an HTML page was touched after its `.md` moved, never that it says the same thing.
  Advisory only, since a styled page renders placeholders its own way. ([#84](https://github.com/actarus314/project-template/pull/84))
- **Add a minimal `.claude-plugin/plugin.json`, so the repo loads as a Claude Code plugin.**
  Nothing is published yet: it exists to make the packaging testable rather than merely assumed. ([#81](https://github.com/actarus314/project-template/pull/81))

### Changed
- **Move every sub-check into `checks/`, leaving the four maintainer commands at the root.**
  The root used to mix what the maintainer runs directly with what `check.sh` merely calls internally — one nature, two treatments. ([#86](https://github.com/actarus314/project-template/pull/86))
- **Trigger every check from the CI, where it actually blocks.**
  Several were reachable only through a manual `./check.sh`.
  The `pre-commit` hook replays it advisory and throttled to 24 hours, so it was never the real net; the pull request is. ([#86](https://github.com/actarus314/project-template/pull/86))
- **Extend the dated-narrative and memories checks to every generated project.**
  They now travel alongside `check.sh`, `open-pr.sh` and `verify-tone.sh`: the conventions in `METHODE.md` hold for any project this repository generates. ([#85](https://github.com/actarus314/project-template/pull/85))
- **Auto-detect which scripts the CI runs `shellcheck` on, instead of listing them by hand.**
  The hand-written list had already fallen one script behind, silently breaking the guarantee that a local run matches the CI. ([#84](https://github.com/actarus314/project-template/pull/84))
- **Run the tree-reading checks at every commit, and block on them, instead of once a day.**
  The `pre-commit` hook used to replay `check.sh` once per 24 hours and only warn; what reads an external base still runs every 6 hours.
  `git commit --no-verify` remains the way through. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Add `./check.sh --commit`, running only the checks meant for every commit.**
  A check that reads the tree still reads all of it, even here — narrowing it to the diff would miss a link broken in a file the diff never mentions. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Cut `check.sh`'s running time by about half (6.25 s to 3.43 s here; 2.08 s for `--commit`).**
  Most of it was never a check: asking each Python tool its version booted an interpreter just to print a string. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Stop `configure-repo.sh` from asking GitHub the same question twice.**
  The repository's visibility, its branches and its workflows were each queried twice, though none of them can change while the script runs. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Run every check under `checks/` in parallel, alongside the external tools, not after them.**
  Their combined time drops to the slowest one instead of the sum (0.90 s to 0.22 s).
  A missing output is treated as an error, never a silent pass. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Rebuild `.ci-tools/venv/` automatically once the project directory moves.**
  Moving the directory used to leave every absolute shebang under it pointing nowhere, `pip` included, with no automatic cure. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Split the project standard by subject, one subject per file, one owner per subject.**
  It had grown to 1012 lines, covering ten subjects also restated by three satellite documents — competing sources.
  Every moved section keeps a one-line pointer, so "standard §5" still resolves. ([#75](https://github.com/actarus314/project-template/pull/75))
- **Make `repo-controls.md` and `security-and-updates.md` own their subjects, not summarise them.**
  Both used to defer to the standard — the definition of a competing source.
  One now owns branch policy and repo configuration; the other, who updates dependencies. ([#76](https://github.com/actarus314/project-template/pull/76))
- **Turn the standard into the index of what it no longer carries.**
  It shrinks from 1012 lines to about 320 and routes every subject to its owner in `docs/`.
  `github-repo-config.md` and its own §11 are removed; section numbers stay stable. ([#77](https://github.com/actarus314/project-template/pull/77))

### Fixed
- **Run three copied checks in every generated project, instead of shipping dead code.**
  `init-project.sh` copied the second-person, dated-narrative and memories checks where `check.sh` never looks.
  The travelling-path check misses this too: an existence test reads it as deliberately absent. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Fix the release order the RUNBOOK taught, which could never be merged.**
  It said to seal the `CHANGELOG` first, then tag — but the version check compares the newest heading to the newest tag, so sealing first makes that very pull request red.
  The tag now comes first, the sealing second. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Make two checks in `configure-repo.sh` speak when they fail, instead of failing silently.**
  The community-profile check had no branch for its own read failing, so it claimed a completeness it never verified; the Pages-homepage step fell through a `case` with no default. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Validate the Renovate configs at the exact pinned version, not a range.**
  The version was read only up to its first dot, turning `renovate@43.288.0` into `renovate@43` — so the local run silently stopped matching what the CI runs. ([#88](https://github.com/actarus314/project-template/pull/88))
- **Restore the `--json` filter to the CI-verification command everywhere it had been dropped.**
  The RUNBOOK, `repo-controls.md` and both templates had lost it, teaching a form of the command that cannot be read workflow by workflow. ([#86](https://github.com/actarus314/project-template/pull/86))
- **Fix the `new-project` skill resolving its own documents wrongly when packaged as a plugin.**
  It assumed its documents sat two levels above it, true only through a symlink.
  Packaged as a plugin, every `docs/…` path resolved against the project being created instead. ([#81](https://github.com/actarus314/project-template/pull/81))

## [1.1.0](https://github.com/actarus314/project-template/releases/tag/v1.1.0) - 2026-08-02

### Added
- **State in the standard that `develop` reading as "N commits behind `main`" is structural, not a bug.**
  The promotion's merge commit lands on `main` only, so the gap grows every cycle and zero is unreachable.
  The measure that decides: `git diff origin/main origin/develop`. ([#70](https://github.com/actarus314/project-template/pull/70))
- **Check the second person in versioned content, and block on it (`verify-tone.sh`).**
  It reads only what is committed, so an untracked scratch file is exempt; exceptions are narrow — licenses, the rule's own wording, one verbatim quotation.
  It ships into every generated project. ([#69](https://github.com/actarus314/project-template/pull/69))

### Changed
- **Translate the last French documents to English, and rename their files to match.**
  `controles-repo` → `repo-controls`, `securite-mises-a-jour` → `security-and-updates`, `verifier-checksums.sh` → `verify-checksums.sh` (`--maj` → `--update`).
  Old names stay under 1.0.0. ([#68](https://github.com/actarus314/project-template/pull/68))
- **Make the README bilingual: English first, then French, separated by `---`.**
  It gains two sections it was missing — Why this exists and What this is not, the second naming real limits: GitHub-only, built for Claude Code, solo-sized, no update path for already-generated projects. ([#68](https://github.com/actarus314/project-template/pull/68))

### Fixed
- **Fix the second person forbidden in versioned content, still present in both documentation pairs, `SECURITY.md`, and four files shipped into every generated project.**
  All now impersonal.
  Already-generated projects keep their frozen copy. ([#68](https://github.com/actarus314/project-template/pull/68))
- **Stop the documentation from claiming two already-shipped controls still need to be built.**
  The pinned local runner and the pinned gitleaks hook exist as `check.sh` and `.githooks/pre-commit`; only the per-language build/test stub remains (`docs/security-and-updates.md`). ([#68](https://github.com/actarus314/project-template/pull/68))
- **Refuse to write a ruleset that requires a status check no job produces.**
  `configure-repo.sh` derived check names from the templates, not the repo's own CI, so a differently-named CI blocked every pull request forever.
  It now refuses first; `--dry-run` reports without writing. ([#67](https://github.com/actarus314/project-template/pull/67))

## [1.0.0](https://github.com/actarus314/project-template/releases/tag/v1.0.0) - 2026-07-31

First tagged version.
The repository went public on this date: everything below had landed before the flip, and is sealed here rather than reconstructed.

### Added
- **Add the community health files the repo prescribes but never had:** `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, and issue/PR templates.
  `SECURITY.md` routes a flaw to a private advisory instead of a public issue; `CONTRIBUTING.md` is written for this repo, not the template. ([#62](https://github.com/actarus314/project-template/pull/62))
- **Give the repo two licenses, not one.**
  The tool is under PolyForm Noncommercial — not open source, despite counting for the community profile — and the files it copies into generated projects are under MIT, so a generated project does not inherit the noncommercial restriction. ([#61](https://github.com/actarus314/project-template/pull/61))
- **Version the repo from a single source: the git tag**, never a stored literal.
  Three scripts gain `--version`, reading `git describe`.
  A ruleset makes the tag immutable, unlike a `VERSION` file or changelog heading; `verify-version.sh` checks they agree, and the CI job fetches tags explicitly. ([#60](https://github.com/actarus314/project-template/pull/60))
- **Stamp a generated project with the template version that scaffolded it**, so a later fix can be checked against what the project actually received.
  The stamp lives in `AGENTS.md`: true about the past, and it does not track the template afterwards. ([#60](https://github.com/actarus314/project-template/pull/60))
- **Add a drift guard between a doc's `.md` source and its hand-made `.html` copy.**
  `docs/verifier-checksums.sh` compares a recorded checksum and fails red on divergence, with the update command.
  Wired into `check.sh` and CI; silent on a generated project, where the script is absent. ([#56](https://github.com/actarus314/project-template/pull/56))
- **Add a weekly Trivy scan of the published image**, for the `--artefact` capability: until now it was scanned only on the pull request, and a stale base image produced no bump, no scan, no warning.
  A schedule only runs from the default branch; a project that stops at `develop` arms nothing. ([#52](https://github.com/actarus314/project-template/pull/52))
- **Require checking the push run on `main` after a merge**, since a pull request's green run says nothing about that different event, and `main` is what ships.
  The rule lives in `AGENTS.md`; the command already documented for this does not find that run. ([#45](https://github.com/actarus314/project-template/pull/45))
- **Grant the working PAT `Administration: read`, never write**, so the assistant can verify a script's claimed settings: security toggles, and classic branch protection, invisible in the rulesets API and able to lock `main` forever.
  Read-only; no rotation needed on an existing PAT. ([#48](https://github.com/actarus314/project-template/pull/48))
- **Bring the new-project skill into the repo as its canonical version**, at `skills/new-project/`, with `~/.claude/skills/new-project` reduced to a symlink.
  It used to live outside any repo: not versioned, not run through CI, not diffable. ([#50](https://github.com/actarus314/project-template/pull/50))
- **Add this changelog file.**
  The standard requires a `CHANGELOG.md` for every generated project, and this repo did not have one. ([#43](https://github.com/actarus314/project-template/pull/43))

### Changed
- **Switch the repo to English.**
  Going public removes the standard's language exemption, which rested on staying private.
  Local-only template files were first wrongly excluded and are translated too; the template's own `README.md` stays bilingual by design, since its French half is the product. ([#57](https://github.com/actarus314/project-template/pull/57))
- **Stop `delete-branch-on-merge` from deleting `develop` itself on a private 3-stage repo.**
  The setting targets the source branch of any merged pull request, so a promotion would take `develop`, with no ruleset in private to stop it.
  Switching to public restores the setting on the next replay. ([#42](https://github.com/actarus314/project-template/pull/42))
- **Widen the `ci-node.yml` and `docker-publish.yml` templates** to a repo whose manifests are not at the root, and to images a third party deploys.
  `ci-node.yml` refuses to pass when its `npm` steps are skipped; `docker-publish.yml` attaches an SBOM and SLSA provenance, signed by digest. ([#41](https://github.com/actarus314/project-template/pull/41))
- **Bump the pinned CI tools:** `zizmor` to 1.28.0, `semgrep` to 1.171.0, and `docker/login-action` to v4.5.2. ([#40](https://github.com/actarus314/project-template/pull/40))

### Fixed
- **Restore, into the `.md`, the incident that justifies opening a pull request even when working solo.**
  Only the hand-made `.html` copy carried the story; the `.md` held a cross-reference.
  Restored anonymized, with no project or host name; a stale revision date is dropped from the `.html`. ([#56](https://github.com/actarus314/project-template/pull/56))
- **Stop two templates from naming a private repo and copying that name into every generated project, including public ones.**
  `ci-node.yml` cited one repo, the template `README.md` cited another; both are replaced by what they taught.
  A project generated before this fix carries the frozen copy. ([#55](https://github.com/actarus314/project-template/pull/55))
- **Stop announcing "Discussions open" without checking it happened.**
  `has_discussions` is not a documented parameter of the `PATCH` call `configure-repo.sh` makes, so the request returns success while activating nothing.
  It re-reads the repo and warns, with the settings URL, when closed. ([#53](https://github.com/actarus314/project-template/pull/53))
- **Stop the runbook from prescribing that a Renovate onboarding pull request be closed.**
  Closing it is the bot's documented opt-out.
  Disabled status lives on Mend's side; committing `renovate.json` reactivates nothing — only a manual scan on the portal does.
  Fixed to leave it open and ask. ([#50](https://github.com/actarus314/project-template/pull/50))
- **Stop the new-project skill from recommending `gh pr checks`**, forbidden here since the Checks permission does not exist in the fine-grained PAT UI, and from setting up a `BACKLOG.md` the template no longer generates.
  Also fixes three smaller drifts from the current runbook. ([#50](https://github.com/actarus314/project-template/pull/50))
- **Fix the PAT recipes announcing stale permissions in four places, two read at creation time.**
  They were missing `Contents: read` and `Issues: read`; a missing permission raises no error.
  Both scripts point to the runbook instead of copying the list, since a copy drifts at the next change. ([#49](https://github.com/actarus314/project-template/pull/49))
- **Correct "never `Administration`" to "never `Administration: write`"**, now that the working PAT carries `Administration: read`.
  Made precise everywhere it appeared: the runbook, the standard, the README, `AGENTS.md`, both scripts, and the checklist. ([#49](https://github.com/actarus314/project-template/pull/49))
- **Stop Dependabot from also targeting production on a 3-stage flow.**
  Its security pull requests always target the default branch, bypassing staging.
  `configure-repo.sh` now disables it there, unless Renovate has been inactive for 14 days — then it keeps the net and says why. ([#47](https://github.com/actarus314/project-template/pull/47))
- **Stop Renovate from targeting production on a `--staging` project.**
  For lack of `baseBranchPatterns`, every pull request, security ones included, landed on `main`, skipping the host the third stage exists to validate.
  `init-project.sh` sets the key on `develop`, only when that branch exists. ([#44](https://github.com/actarus314/project-template/pull/44))
