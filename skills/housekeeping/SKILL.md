---
name: housekeeping
description: Use when the maintainer asks for the development admin to be brought up to date — "fais la passe de fin de chantier", "fais une passe de fin de chantier", "je vais clear", "pour que je puisse clear et repartir", "les suivis sont-ils à jour ?", "repos locaux à jour ?", "tout est en ordre ?" — or when the end-of-turn guard reports that commits have piled up with nothing written down. Brings the tracking doc back in line with the work, files an archive if a stage closed, and says what is still owed.
---

# The closing pass — bringing the admin back in line with the work

## What this settles, and what it never claims

**It settles the ADMIN of development, not the work itself**: what has been done is written where a
cold reader finds it, nothing is left uncommitted by accident, and what is still owed is stated.

🔴 **It never claims the tracking doc is "true".** No pass, and no check, can establish that — the
control that watches the neighbouring workspace says so in its own header, and that is the right
answer. What this pass establishes is that the doc has been **brought up to date deliberately**,
by someone who read the work.

## Step 1 — the inventory

The inventory is countable and decomposable. **Delegating it is a cost question, not a rule** —
the underlying one is *delegate as soon as it costs LESS*
*([`docs/claude-code-setup.md`, "Delegating"](../../docs/claude-code-setup.md))*, and the six `git`
commands below cost less run directly than wrapped in a subagent launch. Delegate when the
inventory actually spans several projects, or when it grows past what one pass reads comfortably;
otherwise run it here.

⚠️ **If it is delegated**: a cheaper model, a parallel workflow over one sequential pass, and a
prompt carrying the three opt-ins — *"does the work itself"*, *"does not re-delegate"*, *"does not
call the advisor"*. A launch omitting any of them is **refused** by `verify-delegation.sh`.

What the inventory brings back, per repository *(the code one and the neighbouring workspace)*:

| Question | Where it is read |
|---|---|
| anything uncommitted? | `git status --porcelain` |
| a local branch never pushed? | `git rev-parse --verify origin/<branch>` |
| a local branch whose remote is GONE — merged, then deleted | `git fetch --prune`, then `git branch -vv \| grep ': gone]'`. 🔴 **Never `--merged main`**: this repository merges by squash, so a merged branch is never an ancestor of `main` and that test returns nothing — measured twice, at the merges of `#117` and `#119`, 0 against 1 both times |
| commits pushed on one subject with no pull request open? | `gh pr list --head <branch>` |
| commits landed since the tracking doc was last written to | `git log --since <last write to the tracking doc>` |
| a `RECHERCHE-*` still sitting on the hot side | the workspace root |
| the newest release, and whether an archive followed it | `git for-each-ref refs/tags` + the archives directory |

## Step 2 — the judgement, which stays here

The inventory counts; **none of the questions below is answered by counting**, which is why this
part is not delegated and not scripted:

1. **Go through the open-work section LINE BY LINE, and state open or closed for each one.**
   Not "does the doc still reflect the work" in the round — that question gets answered *yes* by
   glancing at a document that was written today, which is exactly how four closed items sat in the
   backlog for a full day.
   🔴 **This enumeration and the reading below are WRITTEN DOWN, and the turn does not end without
   them.** The artefact is `~/.local/state/claude-controls/housekeeping-<project>.pass` — one line
   per entry, `<key>: <open|closed|unchanged>`, plus the next concrete gesture where the verdict is
   `open`. Keys are the backlog item numbers and the `##` section titles, read from the tracking doc
   itself, so the total is never a number anyone picked. **Naming an entry without a verdict does not
   count it.** The end-of-turn hook sends the turn back until every entry is covered, at most three
   times, then releases it and publishes what is still missing.
   ⚠️ **The artefact is scratch, not a document.** It lives outside both repositories, it is deleted
   when the tracking doc is written, and nothing ever reads it for state — the tracking doc stays
   the single source.
   🔴 **This enumeration is the only thing that catches a closed item nobody marked.** The check
   that guards this section matches a MARKER, so it sees the ones that were labelled and is blind to
   the rest; measuring staleness instead was tried and failed — the document is rewritten often
   enough that every line looks fresh. There is no counter for this, which is why it is a step here.
   For each line: does its *next concrete gesture* still need doing? If it is done, the item **leaves
   the section** — nothing is marked and left in place.

2. 🔴 **Then READ THE WHOLE TRACKING DOC, top to bottom — every section, not just the open work.**
   A pass that stops at the open-work list leaves the rest to rot, and the rot is not hypothetical:
   on 2026-08-05 a pass did exactly that, and the maintainer then found by hand, in one reading —
   an entry point that stated the finished stage instead of the next gesture · **two sections
   restating the same completed work** · a table broken by two block quotes cutting its header from
   its rows, four rows short of a column · and **three false facts** *(a count of 2 where there were
   9, a cleanup announced as owed and long since done, a stage's control count off by one)*.
   Four questions, on **every** section:
   - **Does the entry point say where to RESUME?** It carries the state and the next concrete
     gesture — never the story of what just shipped.
   - **Is this fact stated anywhere else in the document?** Completed work belongs in **ONE**
     section, everywhere else a link. Two sections listing what was done is the same fact twice, and
     the stale copy is the one that gets read.
   - **Does it still hold?** Re-measure what a command can settle — a count, a version, a branch, a
     path. A fact written once true rots silently, and this document has no diff against reality.
     🔴 **Read the SERVER, not the local cache**, for anything that lives on the forge: a stale
     remote ref made a pass report 19 branches where the forge held 2.
   - **Do the tables still render?** A block quote between a header and its rows breaks the whole
     table; rows must all carry the same number of cells.
   ⚠️ **State what was checked and what could NOT be** — a third-party dashboard, a token's expiry,
   an alert count. Unverifiable is a fine answer; silence reads as verified.

3. **Did a stage close?** A release usually marks one; a fix's pull request does not. Only the
   conversation knows.
4. **If one closed** — the three gestures the METHOD prescribes, in
   [`docs/METHODE.md`, "Closing out a stage"](../../docs/METHODE.md): prune the hot side so the doc
   **shrinks**, write the archive as a **synthesis** (never a dump), file the stage's research
   inside it, then put the memories through the same sieve.
5. **What is still owed** — decisions taken and never written, a pending action that belongs to the
   maintainer, a measurement shown in the conversation and recorded nowhere.

## Step 3 — write, then say what was left

**The tracking doc is the single artefact.** Do not create a handoff file beside it: a second
resume document is a second source, and the METHOD's whole point is that a fact lives in one place.

Then report, in a few lines: what was written, what closed, **and what was deliberately left** —
a pass that silently drops an item reads exactly like a pass that had nothing to drop.

## What this pass never does

- **No WIP commit.** A commit here goes through the same gate as any other; the hook runs the checks
  and blocks on a gap. Nothing is committed to look tidy.
- **No push, no pull request opened, unless asked.** Both are the maintainer's call.
- **No rewriting of an archive.** An archive is immutable once written.
