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

## Step 1 — the inventory, delegated and parallel

The inventory is countable, decomposable, and worth no orchestrator tokens.
**Delegate it, on a cheaper model, and prefer a parallel workflow over one sequential pass** — the
rule, the three opt-ins it requires, and why leaving them unwritten silently does the opposite:
[`docs/claude-code-setup.md`, "Delegating"](../../docs/claude-code-setup.md).

⚠️ A subagent launch whose prompt omits *"does the work itself"*, *"does not re-delegate"* or
*"does not call the advisor"* is **refused** by `verify-delegation.sh`. Write the three.

What the inventory brings back, per repository *(the code one and the neighbouring workspace)*:

| Question | Where it is read |
|---|---|
| anything uncommitted? | `git status --porcelain` |
| a local branch never pushed? | `git rev-parse --verify origin/<branch>` |
| commits pushed on one subject with no pull request open? | `gh pr list --head <branch>` |
| commits landed since the tracking doc was last written to | `git log --since <last write to the tracking doc>` |
| a `RECHERCHE-*` still sitting on the hot side | the workspace root |
| the newest release, and whether an archive followed it | `git for-each-ref refs/tags` + the archives directory |

## Step 2 — the judgement, which stays here

The inventory counts; **none of the questions below is answered by counting**, which is why this
part is not delegated and not scripted:

1. **Does the tracking doc still reflect the work?** Not "has it been touched" — whether a cold
   reader, human or AI, would find where things stand and what remains.
2. **Did a stage close?** A release usually marks one; a fix's pull request does not. Only the
   conversation knows.
3. **If one closed** — the three gestures the METHOD prescribes, in
   [`docs/METHODE.md`, "Closing out a stage"](../../docs/METHODE.md): prune the hot side so the doc
   **shrinks**, write the archive as a **synthesis** (never a dump), file the stage's research
   inside it, then put the memories through the same sieve.
4. **What is still owed** — decisions taken and never written, a pending action that belongs to the
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
