# METHOD — a single source of truth

> **Rule set by the maintainer on 2026-07-14, after having to reorder three consistency passes.**
> **It is not up for debate. It applies to EVERY write, in THIS project and in every one it generates.**

---

## The rule

**A fact lives in ONE SINGLE place. Everywhere else: a link — never a copy.**

The problem is not a document's length: it is **competition between multiple sources**.
When the same fact is written in the script, the runbook, the conventions *and* the tracking doc, **the four copies diverge** — it is mechanical. And the day one of them lies, it becomes a circular search for which one to believe.

> **This is not a hypothesis.** `configure-repo.sh` carried a comment stating *"CodeQL: via the committed workflow, nothing to activate here"* — **sixty lines above the code that does exactly that activation**. The script was contradicting itself, and this was the comment reread to decide.

---

## Where each thing lives — by ROLE, not by file name

The roles below are **stable**; the files that carry them are not *(see "The tracking tool is a default")*.

> **This table states the NATURE of a document. Which SUBJECT belongs to which file, and who owns it,
> is [`claude-code-project-standard.md`](claude-code-project-standard.md)** — *"one subject, one owner"*,
> and it is the index. A fact's owner must be **identifiable without searching**: that is the whole
> reason `docs/` holds several files rather than one.

| Role | Contains | **NEVER contains** |
|---|---|---|
| **THE TRACKING DOC** *(default: `workspace/docs/SUIVI.md`)* | Where things stand · decisions · pitfalls · **what remains** *(brief — POINTS to a plan if it's heavy)*. **Enough for a human OR an AI to pick back up cold.** | the detail of the evidence · the story of the bugs · the long why · **what has shipped** *(purged)* · full plans |
| **THE ARCHIVES** *(default: `workspace/docs/archives/<stage>/`)* | **THE DETAIL.** The why, the how, the evidence, the measurements, the sources. **Dated, by phase or by topic.** | — *(it's the overflow: it can grow)* |
| **THE ACTIONS** *(`RUNBOOK.md`)* | The actions, in **ORDER**, and **WHO performs them**. The URLs, the exact values, the pitfalls. | the why *(→ conventions)* · the history *(→ archives)* |
| **THE CONVENTIONS** *(`claude-code-project-standard.md`, the ADRs)* | The rules and the **WHY** behind each rule. | the procedure *(→ runbook)* · the story of incidents *(→ archives)* |
| **THE CODE** *(scripts, workflows)* | **what the code CANNOT say**: a non-obvious constraint, a pitfall that would recur. | **the historical narrative.** Never *"observed on 14/07 on test003…"* |
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
> **Everything the script LEARNS must FLOW BACK to the doc.** A fact discovered while running it *(the personal/org ghcr behavior, discovered through testing)* has no right to live **only** in the script: the doc would stop being enough to do it **by hand**, and it would become wrong by omission.
>
> ⚠️ **What this does NOT mean**: "the doc must say everything". That would be the door to bloat — exactly what this fights against. The **standard** states the conventions, the **runbook** states the actions, the **script** keeps its technical constraints.

✅ **Keep** — a constraint that would recur if ignored:
```bash
# `gh api` writes its errors to STDOUT: `$(gh api … || echo x)` produces '{"message":…}x'.
```

❌ **Delete** — the narrative, the evidence, the date, the incident:
```bash
# This pitfall struck FOUR times in this file, twice of them after being documented:
#   · the run_id of the PATCH → the script announced "✓ CodeQL ENABLED" on a PRIVATE repo…
#   (Observed on test005, 2026-07-14.)
```
→ **That goes to the archive.** One line in the code, the full narrative in the archives.

**Deleting a comment is NOT losing the information**: it lives in the archive, dated, with its evidence. **It is simply in the right place.**

---

## The tracking doc — a PRINCIPLE, not mandated files

> 🔴 **The template initializes EVERY project — including ones later run by a third-party management system** *(GSD, superpowers, or other)*.
> **Forcing our tracking files on them would COLLIDE with theirs** *(`.planning/` & co.)*, and **two competing tracking systems in one project means zero system actually kept up**. **ONE gets chosen.**

**What the tracking doc must be is stated in the table above.** What matters here is that it is a **ROLE, not a file**: GSD's `.planning/`, a Linear, a Notion satisfy it just as well, as long as a fact keeps living in a single place. A resume doc that accumulates the shipped stops being one — **it becomes a journal**.

**Goal**: for a human **or** an AI reopening the project 6 months later to find their footing **without reading a wall of text**.

`SUIVI.md` is what the generator sets up **by default**, in `workspace/docs/` *(never pushed)*: **one single living doc** carrying the cold-resume state *(state, environments, history, decisions, pitfalls)* **and "what's left to do"** *(brief)*. A heavy undertaking moves into a **plan** *(`workspace/plans/`)*. Not wanting them at all: `init-project.sh --no-lifecycle-docs`.

> ⚠️ **BEFORE creating anything to drive a project** — tracking, backlog, planning, context resumption — **CHECK WHAT ALREADY EXISTS**: installed skills and agents *(around a hundred, including all of **GSD**: `gsd-progress`, `gsd-resume-work`, `gsd-pause-work`…)*, plugins, marketplace, native features. *(`find-skills` exists exactly for this.)*
> **Only build custom as a last resort** — and say so.

---

## The main documents stay SHORT

**If they grow, the detail MOVES TO THE ARCHIVE — it does not get crammed in.**

A document no one rereads is no longer of any use. The runbook is read **while doing** the work: if it is unreadable, it goes unread, and the action gets done from memory — **and an action recited from memory is a wrong action**.

**Too many archive files is NOT a problem** — as long as the links are there and honored.
**A light directory structure** is better than 25 `.md` files at the same level mixing living documents with archives.

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
5. **Put the MEMORIES through the same sieve** — they are the 6th location, and **the only one without Git structure: no diff shows them, so they get missed by default.**
   - **whatever has become FALSE gets corrected, or disappears.** *(A false memory is worse than none: it gets recalled automatically at startup, with authority.)*
   - **what a versioned document now carries gets reduced to a pointer** — except for the **lived narrative** *("it happened, here is the measure")*, which explains why the rule exists and which the document itself does not carry.
   - **check the index** *(`MEMORY.md`)*: a memory absent from the index is **never** recalled, and a broken `[[x]]` link is flagged by nothing.

**The directory structure stays LIGHT**: a few stage folders, a few useful files each — **neither a giant freezer, nor 38 folders of two 90-line files.**

> 🔴 **The trap — and it has been committed** *(15/07)*: **freezing the verbatim** of `SUIVI` into a single 114 KB block. A freezer that **never gets opened**: if finding the *why* behind a line on the hot side requires digging through the huge archive, **it will not get done**. The archive gets **synthesized**; it does not get **dumped**.

---

## What is ARMED — and how far a rule travels

**A rule held by discipline alone is a rule that gets re-established by periodic manual passes — never a rule that holds.** These rules are armed: `check.sh` runs them.

**The list of checks, their perimeter, their rhythm, their gate and what they cost live in
[`repo-controls.md`](repo-controls.md)** — the document that owns the control matrix — **and nowhere
else.** Three partial copies of that list once coexisted, and the three disagreed on how many there
were.

**What belongs HERE is the question that decides a perimeter**, because it is a question of writing:

> 🔴 **The discriminator is the NATURE of the rule.** A rule of **method** *(one fact one place, no dated narrative, the memories)* follows the method **everywhere** — into the neighbouring `workspace/` included. A rule of **published style** *(English, no second person)* **stops where publication stops.**

**Why `verify-tone.sh` stops at `repo/`, and it is not an oversight.** The second person is a rule of published style, paired with the one imposing English on versioned content. `workspace/` is deliberately in **French** and never leaves the machine: extending the check there would import a rule from a perimeter explicitly exempt from its twin. *(Measured: 23 hits, mostly quotations — an npm error message, the text of a stub.)*

---

## The reflex, on every write

Before adding a piece of information, **a single question**:

> **"Does this fact already exist elsewhere?"**

- **Yes** → **put a link**, and fix the original spot if it is wrong.
- **No** → **what is its ONE place?** The tracking doc, the archive, the runbook, the conventions, or the code. **One.**

**And if a document grows: nothing gets crammed in — the detail comes out.**

---

## Delegating: Claude is the orchestrator

→ **[`claude-code-setup.md`](claude-code-setup.md)** — when to delegate, and the three instructions a subagent prompt must carry *(it does the work itself · it does not call the advisor · it runs on a cheaper model)*.

🔴 **These three are OPT-INS**: left unwritten, the default does the opposite of all three, silently.
