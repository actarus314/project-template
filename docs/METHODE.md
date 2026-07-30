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

## The tracking tool is a DEFAULT, not a dogma

`SUIVI.md` is what the generator sets up **by default** *(the tracking doc AND "what remains" in a single living doc; a heavy undertaking moves into a plan)*. It is the **roles** that matter, not the files: GSD's `.planning/`, a Linear, a Notion **satisfy the same rule** as long as a fact keeps living in **a single place**.

- What each document must carry: **`claude-code-project-standard.md` §16**.
- Not wanting them at all: `init-project.sh --no-lifecycle-docs`.
- 🔴 **Two tracking systems in parallel = two competing sources** — precisely what this rule forbids. **ONE gets chosen.**

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

## The reflex, on every write

Before adding a piece of information, **a single question**:

> **"Does this fact already exist elsewhere?"**

- **Yes** → **put a link**, and fix the original spot if it is wrong.
- **No** → **what is its ONE place?** The tracking doc, the archive, the runbook, the conventions, or the code. **One.**

**And if a document grows: nothing gets crammed in — the detail comes out.**

---

## Delegating: Claude is the orchestrator

**As soon as a task costs LESS delegated** — or it is **noticeably faster or more capable at equal cost** *(or very slightly higher)* — **Claude takes the orchestrator role and delegates** to one or more subagents.

- The subagent **does the work itself**: it does not re-delegate, and it **does not call the advisor**.
- It often runs on a **faster and cheaper** model *(Sonnet, or even Haiku)* — the orchestrator keeps the reasoning, the agent executes.
- **Prefer workflows** *(deterministic orchestration: parallel fan-out, pipeline, adversarial verification)* **as much as possible and as much as relevant**: a task that breaks down into parallel tasks or verifiable steps benefits from being a workflow rather than one long sequential pass.

The goal: the orchestrator spends its tokens **deciding**, not executing what a lighter model does just as well.
