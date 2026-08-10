# METHOD — a single source of truth

> **Rule set by the maintainer on 2026-07-14, after having to reorder three consistency passes.**
> **It is not up for debate. It applies to EVERY write, in THIS project and in every one it generates.**

---

## The rule

**A fact lives in ONE SINGLE place. Everywhere else: a link — never a copy.**

The problem is not a document's length: it is **competition between multiple sources**.
Written in the script, the runbook, the conventions *and* the tracking doc, **the four copies diverge** — mechanically — and the day one lies, finding which to believe is a circular search.

> **This is not a hypothesis.** `configure-repo.sh` carried a comment stating *"CodeQL: via the committed workflow, nothing to activate here"* — **sixty lines above the code doing exactly that activation**, and it was the comment reread to decide.

---

## Where each thing lives — by ROLE, not by file name

The roles below are **stable**; the files that carry them are not *(see "The tracking tool is a default")*.

> **This table states the NATURE of a document. Which SUBJECT belongs to which file, and who owns it, is [`claude-code-project-standard.md`](claude-code-project-standard.md)** — *"one subject, one owner"*, and it is the index. A fact's owner must be **identifiable without searching**: that is the whole reason `docs/` holds several files rather than one.

| Role | Contains | **NEVER contains** |
|---|---|---|
| **THE TRACKING DOC** *(default: `workspace/docs/SUIVI.md`)* | **TWO things and no others: what is going to be done, and what has been done.** The open work — one list, never two — and one line per closed stage pointing at its archive. **Enough to pick back up cold.** | the evidence · the story of the bugs · the long why · **what has shipped** *(purged from HERE to the archive, never lost)* · full plans · **what is settled or what bites** *(→ below)* |
| **THE SETTLED** *(default: `workspace/ACQUIS.md`)* | **what NOTHING CAN BE DONE ABOUT**: a decision made, a fact proven, a structural limit. Consulted, not told. | 🔴 **a defect that could be fixed** — filed here it becomes a fatality instead of being repaired *(done once, on 2026-08-08)*. A gap is WORK: it belongs in the tracking doc, and an item here asking for one is the second backlog this split forbids |
| **WHAT BITES** *(default: `workspace/PIEGES.md`)* | the traps that already cost once **and attach to no single gesture**, read **before** acting. A trap a check now covers **leaves**: an armed rule need not be known. | the same — no open work, or the split collapses into two lists · **a trap that belongs to one gesture** *(→ the runbook, at that gesture)* |
| **THE ARCHIVES** *(default: `workspace/docs/archives/<stage>/`)* | **THE DETAIL.** The why, the how, the evidence, the measurements, the sources. **Dated, by stage or topic.** | — *(the overflow: it can grow)* |
| **THE ACTIONS** *(`RUNBOOK.md`)* | The actions, in **ORDER**, and **WHO performs them**. The URLs, the exact values, and **the trap OF A GESTURE — the one that bites while performing it**. | the why *(→ conventions)* · the history *(→ archives)* · **a trap belonging to no gesture** *(→ what bites, above)* |
| **THE CONVENTIONS** *(`claude-code-project-standard.md`, the ADRs)* | The rules and the **WHY** behind each rule. | the procedure *(→ runbook)* · the story of incidents *(→ archives)* |
| **THE CODE** *(scripts, workflows)* | **the constraint ITSELF, in one sentence** — what breaks if this line is written otherwise. Addressed to whoever is about to edit it. | **the historical narrative** *(never "observed on 14/07 on test003…")* · **a figure, an alternative weighed, an incident** *(→ the note below)* |
| **THE IMPLEMENTATION NOTES** *(`docs/code/<file>.md`)* | **what it took to arrive at that line**: the **measurement** that set a value, the alternatives ruled out and why, what a reader needs in order to CHALLENGE the design. A subject file's annex, and it **travels with the file it documents**. | the rule *(→ this file, `AGENTS.md`)* · the perimeter, the trigger, the threshold VALUE *(→ the subject file that owns them)* · the dated story *(→ archives)* · **the comment restated in other words** |
| **THE MEMORIES** *(`~/.claude/projects/<project>/memory/`)* | the **reflex** to wake up at startup: a constraint that gets broken **by default**, and the **short story** that says why it exists. | what a **versioned** document already carries *(→ a pointer is enough)* · a fact without the action that follows from it |

---

## Comments in the code — the rule that hurts the most

**The code says what it DOES. The comment says ONLY what the code cannot say.**

> **The deciding criterion, and it is mechanical: A SCRIPT IS THE AUTOMATION OF A PRESCRIPTION WRITTEN ELSEWHERE.**
> The action exists **first** in the runbook, the rule **first** in the conventions. The script does not invent them — **it executes them**. Hence:
>
> | The comment explains… | Verdict |
> |---|---|
> | **a rule, a why, a GitHub default** *("the ghcr package is private by default in an org")* | **copy of the doc → DELETE**, leave a pointer. The fact lives **in the doc**. |
> | **an implementation constraint** *("`gh api` writes its errors to STDOUT")* | **exists nowhere else, and has no business in the doc → KEEP.** |
>
> 🔴 **And the constraint works in the OTHER DIRECTION too — that's where its value is.**
> **Everything the script LEARNS must FLOW BACK to the doc.** A fact living **only** in the script leaves the doc no longer enough to do the work by hand — wrong by omission.
> ⚠️ **What this does NOT mean**: "the doc must say everything". That would be the door to bloat — exactly what this fights against. The **standard** states the conventions, the **runbook** states the actions, the **script** keeps its technical constraints.

> 🔴 **Where the comment stops and its note starts — the two used to claim the same object.** Both were given "the constraint", and neither said which one arbitrates: **32 pairs** of a script and its note scored as restating each other, up to 0,97. That is the mechanical consequence, not carelessness.
> **The test is what the sentence CARRIES: a figure, an alternative ruled out, or an incident belongs to the note.** The comment keeps the constraint bare — enough not to break the line while editing it; the note keeps what it took to get there — enough to challenge the design. Neither is a summary of the other.

A comment worth keeping states a constraint that would recur if ignored; one worth deleting recounts the incident, with its date and its evidence. **That narrative goes to the archive** — one line in the code, the story there — so deleting it loses nothing, it puts it in the right place. Both worked through on a real pair: [`docs/code/verify-narrative.md`](code/verify-narrative.md).

---

## The tracking doc — a PRINCIPLE, not mandated files

> 🔴 **The template initializes EVERY project — including ones later run by a third-party system** *(GSD, superpowers, or other)*.
> **Forcing our files on them would COLLIDE with theirs** *(`.planning/` & co.)*: **two competing tracking systems means none kept up**. **ONE gets chosen.**

**It is a ROLE, not a file**: GSD's `.planning/`, a Linear, a Notion satisfy it just as well, as long as a fact keeps living in a single place. A resume doc that accumulates the shipped **becomes a journal**. **Goal**: a human **or** an AI reopening the project 6 months later finds their footing **without a wall of text**.

`SUIVI.md` is what the generator sets up **by default**, in `workspace/docs/` *(never pushed)*: **one single living doc** carrying the cold-resume state **and "what's left to do"**. A heavy undertaking moves into a **plan** *(`workspace/plans/`)*. Not wanting them at all: `init-project.sh --no-lifecycle-docs`.

**The two rows above are a matter of SCALE, not a second system.** A new project keeps ONE file — three near-empty ones cost more to keep in step. The split comes when the doc stops answering *"what do I do next"* at a glance: measured here on 2026-08-08, **160 of its 263 lines held nothing anyone could act on**. The rule stated there is what holds it together, and the file names are a default, as `SUIVI.md` is.

> ⚠️ **BEFORE creating anything to drive a project** — tracking, backlog, planning, resumption — **CHECK WHAT ALREADY EXISTS**: installed skills and agents *(around a hundred, all of **GSD** among them)*, plugins, marketplace, native features. **Only build custom as a last resort** — and say so.

---

## Concision and plainness — in EVERY piece of writing, not just the documents

**Rule set by the maintainer on 2026-08-07**, covering **everything written**: documents, comments, commit messages, a check's output, a reply.

- **Concise.** One idea per sentence, one sentence per line. Nothing said twice, no sentence that survives only because deleting it would take a decision.
  🔴 **The test is a DELETION, and it holds in every register** — code, prose, comment, terminal output: remove the word, the sentence, the line, and **if nothing breaks, it stays removed.** What makes it usable is that it asks about the EFFECT of the removal, never about the worth of the text. *(Anthropic states it for a rules file: "would removing this cause Claude to make mistakes? If not, cut it.")*
- **Plain.** No jargon that a plainer word replaces, no emphasis carrying no meaning. A reader who knows the subject and a reader who does not must reach the same understanding.

> 🔴 **A size CEILING was considered and RULED OUT**, and the reason matters: capping a file pushes the overflow into sub-files, which moves the problem and risks losing what gets moved. **Concision is written in, never enforced by a wall.**

**One sentence, one line — and no width imposed on top of it.** The break follows the meaning, so a diff shows the sentence that changed rather than the paragraph around it. 🔴 **Wrapping at a column is a layout frozen into the file**: the renderer rejoins those lines anyway. `verify-line-form.sh` refuses a sentence cut across two lines; third-party texts keep the upstream's own layout.

⚠️ **A width THRESHOLD was measured and rejected**, and the reason outlives this rule: *"median 92 characters per line"* came from a corpus that was itself hard-wrapped — calibrated on exactly what it was meant to reform, like the changelog's old 750-character cap. **A threshold comes from a reference or an objective, never from the average of what is being corrected.** One sentence per line is binary, so it can be armed at all.

**What can be measured is measured; the rest is not.** Jargon and clarity are judgements: no script reads them, and a model blocking on them is worse than nothing — a green light given wrongly has no second line of defence.

## The four places a change is written — and what each OWNS

**One change is written four times, and the copies diverge unless each owns what the others do not.**

| Where | Owns | Never carries |
|---|---|---|
| **The commit** | the intention — what was broken, why this solution | the *how* *(the diff shows it)* · the story of the search |
| **The pull request** | the **demonstration** — what was measured, what was ruled out, how to verify | a retelling of the diff |
| **`CHANGELOG.md`** | the **effect** for whoever uses the repo, capped, ending on the pull request that delivered it *(standard §16)* | the demonstration |
| **The GitHub Release** | **nothing of its own** — the auto-generated pull-request list, plus the version's CHANGELOG block, copied | prose written for the occasion |

**A commit subject is an imperative sentence of at most 72 characters**, capitalised, no final full stop, then a blank line — where that wall comes from: [`docs/code/verify-commit-form.md`](code/verify-commit-form.md).

🔴 **The Release was the one drifting**: written by hand, it re-told the CHANGELOG in other words — a third rendering nothing could check. Copied, it becomes mechanical *(sources and mechanism: [`docs/code/release-notes.md`](code/release-notes.md))*.

## The main documents stay SHORT

**If they grow, the detail MOVES OUT — to the archive, or to the file that owns it. It does not get crammed in.** A document no one rereads is of no use: the runbook is read **while doing** the work, and unread, the action gets done from memory — which is a wrong action.

**Many files is not the problem, as long as the links are honored** — a light directory structure beats 25 `.md` at one level mixing living documents with archives.

---

## Closing out a stage — the recurring action *(the tracking doc breathes)*

**The docs are an undertaking of their own, at two temperatures:**
- **HOT** — `SUIVI.md`: what is *in progress* and *upcoming*. It **grows** during a stage.
- **COLD** — `archives/<stage>/`: what is *closed*. **One folder per finished stage, its research and its evidence inside.**

**At EVERY finished stage** *(an undertaking, a phase, a batch — not every commit)*:

1. **Prune the hot side.** Take out of `SUIVI.md` everything the stage closed. It **shrinks** — that is the sign the stage is finished.
2. **Write the stage's archive — a SYNTHESIS, NEVER a move or a dump** *(ADR format: context → decisions → consequences)*:
   the sources get **read in FULL**, then distilled into the **WHAT** *(what was done)* **+ the HOW** *(the pitfalls encountered)* **+ the WHY** *(why these choices, what got ruled out)*.
   Goal: **enough to NEVER reopen a closed topic for lack of information — and not one line more.**
3. **File the stage's research and evidence there** *(a `RECHERCHE-*` is cold once done — it goes into ITS stage folder, not at the root of the hot side)*.
4. **Commit.** The archive is immutable *(except for a project paradigm shift)*.
5. **Re-read the SETTLED and the TRAPS**, where they have been split off *(previous section)*: the stage adds what it established and what bit it, and **removes what it made false** — a settled fact turned false is worse than none, and a trap an armed check now covers no longer has to be known. **This is the only moment they are touched**; between two closures, nothing.
6. **Put the MEMORIES through the same sieve** — they are the 6th location, and **the only one without Git structure: no diff shows them, so they get missed by default.**
   - **whatever has become FALSE gets corrected, or disappears.** *(A false memory is worse than none: it gets recalled automatically at startup, with authority.)*
   - **what a versioned document now carries gets reduced to a pointer** — except for the **lived narrative** *("it happened, here is the measure")*, which explains why the rule exists and which the document itself does not carry.
   - **check the index** *(`MEMORY.md`)*: a memory absent from the index is **never** recalled, and a broken `[[x]]` link is flagged by nothing.

**The directory structure stays LIGHT**: a few stage folders, a few useful files each — **neither a giant freezer, nor 38 folders of two 90-line files.**

> 🔴 **The trap — and it has been committed** *(15/07)*: **freezing the verbatim** of `SUIVI` into a single 114 KB block. A freezer that **never gets opened**: if finding the *why* behind a line on the hot side requires digging through the huge archive, **it will not get done**. The archive gets **synthesized**; it does not get **dumped**.

---

## What is ARMED — and how far a rule travels

**A rule held by discipline alone is a rule that gets re-established by periodic manual passes — never a rule that holds.** These rules are armed: `check.sh` runs them.

**The list of checks, their perimeter, their rhythm, their gate and what they cost live in [`repo-controls.md`](repo-controls.md)** — the document that owns the control matrix — **and nowhere else.** Three partial copies of that list once coexisted, and the three disagreed on how many there were.

**What belongs HERE is the question that decides a perimeter**, because it is a question of writing:

> 🔴 **The discriminator is the NATURE of the rule.** A rule of **method** *(one fact one place, no dated narrative, the memories)* follows the method **everywhere** — into the neighbouring `workspace/` included. A rule of **published style** *(English, no second person)* **stops where publication stops.**

Worked through on one case — why `verify-tone.sh` stops at `repo/`, and it is not an oversight: [`docs/code/verify-tone.md`](code/verify-tone.md).

---

## The reflex, on every write

Before adding a piece of information, **a single question**:

> **"Does this fact already exist elsewhere?"**

- **Yes** → **put a link**, and fix the original spot if it is wrong.
- **No** → **what is its ONE place?** The tracking doc, the archive, the runbook, the conventions, or the code. **One.**

**And if a document grows: nothing gets crammed in — the detail comes out.**

---

## Delegating: Claude is the orchestrator

→ **[`claude-code-setup.md`](claude-code-setup.md)** — when to delegate, the three instructions a subagent prompt must carry, and why all three are opt-ins whose omission is silent.
