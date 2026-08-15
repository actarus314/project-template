# `checks/verify-workspace.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why this check exists at all

Why `workspace/` has no remote is stated once, in `AGENTS.md`. What it costs: no remote means no diff-vs-origin, no CI, no pull request, and `check.sh` runs inside `repo/` without looking beside it — missed **four times** before this check existed. *(What it can and cannot verify is the script's own header, and stays there.)*

## A tracked NAME betrays, not the content

Why a filename is enough to flag belongs to [`verify-secret-blindspots.md`](verify-secret-blindspots.md). Here it applies to the one place gitleaks never reaches: the neighbour.

## ONE tracking system, not one file

The rule — one tracking system, whichever it is — is `METHODE.md`'s to state. Counting files named `SUIVI|TRACKING|PROGRESS.md` was blind to the collision METHODE forbids: a `.planning/` beside a `SUIVI.md` is two systems for one question, and the stale one gets read first. Measured: such a workspace returned the same "1 tracking doc" as one holding nothing else — the count had to become one of *systems*.

**The `OTHERS` list cannot be complete**, so it is named in the verdict. **What it still cannot see**: tracked top-level dot-directories, NAMED in `unlisted` and never a fault by themselves — flagging an unknown one on sight would fire on the next tool that ships one.

## Backlog hygiene: a form, not a state

METHODE's rule — the backlog holds OPEN work only — is written in the tracking doc itself, closure markers having once piled up there until it stopped answering "where do I put the effort".

It broke again the same day, four markers deep, unseen: growth read **+24 % against a 25 % threshold** — but growth is the SYMPTOM. The rule is binary, so it needs no threshold at all.

⚠️ **It matches a FORM, never a state**: an item finished, left in place and never marked at all is invisible to it. The marker is a habit, and a check rested on a habit inherits its reliability.

🔴 **And it counts only at the START of a cell.** Anywhere else the marker is a MENTION: the very row describing this rule quotes `des lignes passent à ✅`, and a loose match once read that sentence itself as a closed item.

## The other direction: open work living OUTSIDE the tracking doc

Splitting the tracking doc into neighbours recreates the separate backlog METHODE forbids. **A file DECLARES it holds none**, with `<!-- no-open-work -->`, and only declared files are read — a name would be wrong twice over, METHODE making those names a default and the conformity checklist beside them carrying **58 empty boxes**.

**A closing archive is read while still uncommitted** — the only moment worth looking at, an archive being immutable once committed.

🔴 **Two patterns were measured before the mark was used.** Anything resembling an action returned **7 hits for 1 real leftover**, the other six being the rule quoting itself. Narrowing it to a turn of phrase kept the same flaw, since one is met inside a quotation exactly as inside an instruction — **three commits blocked in one day**, the third on the file explaining the guard, and each repaired by rewording rather than by the guard. It matches the **mark** a task carries, `⬜` and the empty checkbox: a mark is declared, a phrase is met.

## A document has to be able to document the guard that reads it

Writing what a form rule looks for is enough to trip it, and no rule can tell a quotation from an instruction — the same failure the forbidden-command hook pays for with heredocs, and the wiring check with code lines. **A line carrying `<!-- workspace-self -->` is skipped**, by every rule here that reads a line, and the verdict publishes how many. **The convention is already here** — `verify-tone`'s `ALLOW`, `verify-language`'s `fr-pattern` — and it is per LINE: a file-wide exemption would silence the rules for everything else the file says.

## The chantier number given twice

A number identifies a chantier for good — an archive written today must still resolve in six months. Nothing enforced it: the tracking doc holds the OPEN ones, archives the CLOSED ones, no place the union.

🔴 **It had already broken twice, found by hand**: two July folders claim numbers the project later reassigned, and one number named a closed chantier and an open one at once. **It is read from the FIRST cell of a table row, never from prose** — a number in a sentence is a reference, not a claim to it.

⚠️ **It compares OPEN rows only, and the verdict says `duplicates only`.** Extending it to closed chantiers was written and dropped: archives state coverage in prose, one such sentence marking three OPEN chantiers as closed and another saying a chantier *is not* closed. **The case that happened stays invisible, and saying so beats a pattern firing on the wrong rows.**

➡️ **What would close it is a declaration, not a cleverer pattern**: an archive stating its chantiers in a field, the way a check declares `# blocking:`.

## The FORM of a task, and why only five rules of it are here

Seven rules were settled; two were already armed elsewhere, five are here. A task opens on a mark and a `chantier.rank` number, then an **infinitive verb**; it holds **no link** — those live in the detail cell — and at most **72 characters** of bare text.

🔴 **72 is the commit-subject limit, and that is the whole reason it is 72** — a subject and a task are the same object, and `verify-commit-form` already caps one at that value.

**The infinitive is the only binary substitute for "no retelling"**, which is a judgement and stays unarmed. An owner prefix is stripped first: `**Name** :` is not the verb, and the two tasks that failed were that shape.

**The `DETAILS.md` rule names the file, never "a file"**: a stage folder holds several. ⚠️ **It applies only where the prefix names an OPEN chantier** — a side channel, a dead chantier and a pre-numbering folder carry none, and demanding one there invents work.

## Four more rules, and what each refuses

- **The detail column carries a link, or the DASH saying there is nothing to point at yet.** A frozen chantier has no folder, and one invented to satisfy the rule reads as a folder something was lost from — which is why an empty `WIP/` folder is refused outright.
- **A stage folder is prefixed with its chantier number, three digits then `--`.** `000` where the number is impossible: the July archives predate the numbering, and a retroactive number would collide with one since reassigned.
- **A `DETAILS.md` names only numbers the tracking doc still carries**, or a deleted task leaves a section reasoning nothing — the second backlog METHODE forbids. Numbers are read from the START of a heading: further in, a number is a citation, `arXiv:2603.00539` having been the false positive that showed it.
