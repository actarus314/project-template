# `checks/verify-workspace.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why this check exists at all

Why `workspace/` has no remote is stated once, in `AGENTS.md`. What it costs: no remote means no diff-vs-origin, no CI, no pull request, and `check.sh` runs inside `repo/` without looking beside it — missed **four times** before this check existed. *(What it can and cannot verify is the script's own header, and stays there.)*

## A tracked NAME betrays, not the content

Why a filename is enough to flag belongs to [`verify-secret-blindspots.md`](verify-secret-blindspots.md). Here it applies to the one place gitleaks never reaches: the neighbour.

## ONE tracking system, not one file

The rule — one tracking system, whichever it is — is `METHODE.md`'s to state. Counting files named `SUIVI|TRACKING|PROGRESS.md` was blind to the collision METHODE forbids: a `.planning/` beside a `SUIVI.md` is two systems for one question, and the stale one gets read first. Measured: such a workspace returned the same "1 tracking doc" as one holding nothing else — the count had to become one of *systems*. **The `OTHERS` list cannot be complete**, so it is named in the verdict, and tracked top-level dot-directories are NAMED in `unlisted` without ever being a fault by themselves — flagging an unknown one on sight would fire on the next tool that ships one.

## Backlog hygiene: a form, not a state

METHODE's rule — the backlog holds OPEN work only — is written in the tracking doc itself, closure markers having once piled up there until it stopped answering "where do I put the effort".

It broke again the same day, four markers deep: growth read **+24 % against a 25 % threshold** and stayed silent — growth is the SYMPTOM, and a binary rule needs no threshold.

⚠️ **It matches a FORM, never a state**: an item finished, left in place and never marked at all is invisible to it. The marker is a habit, and a check rested on a habit inherits its reliability.

🔴 **And it counts only at the START of a cell.** Anywhere else the marker is a MENTION: the very row describing this rule quotes `des lignes passent à ✅`, and a loose match once read that sentence itself as a closed item.

## The other direction: open work living OUTSIDE the tracking doc

Splitting the tracking doc into neighbours recreates the separate backlog METHODE forbids. **A file DECLARES it holds none**, with `<!-- no-open-work -->`, and only declared files are read — a name would be wrong twice over, those names being a METHODE default and the checklist beside them carrying **58 empty boxes**.

**A closing archive is read while still uncommitted** — the only moment worth looking at, an archive being immutable once committed.

🔴 **Two patterns were measured before the mark.** Anything resembling an action returned **7 hits for 1 real leftover**, the other six being the rule quoting itself; narrowing it to a turn of phrase kept the flaw, one being met inside a quotation as readily as inside an instruction — **three commits blocked in one day**, the third on the file explaining the guard. It matches the **mark** a task carries: a mark is declared, a phrase is met.

## A stage file holds no task, so no exemption protects one

A per-line exemption marker was built here — writing what a form rule looks for is enough to trip it — then **removed the same day, and the reason is worth keeping**: the rules that would honour it read only the tracking table and the `DETAILS.md` headings, neither of which documents its own rules. Zero lines ever used it.
➡️ **The one file that does hold marks — a stage file quoting the tracking doc — is where no exemption belongs**: it carries no task, quoted or not, and one there reopens the second backlog. **Naming a mark instead of showing it** costs nothing.

## A plan, recognised by its header rather than by its name or its boxes

The plan skill stamps the same header on every plan it writes, so a literal identifies one. **A file name would identify nothing**: no convention here fixes what a plan is called, and naming one would invent the very perimeter the literal makes unnecessary.

🔴 **The checkbox was measured and ruled out, because it points backwards.** The pattern reading open work looks for an EMPTY box; replayed over the three states one real plan went through, it returns **11** hits on what the plan stage renders, **4** mid-execution, and **none** once every box is ticked. Armed on a plan, it would bite at birth and stay silent through the drift.

📏 **Measured across both repositories before arming: the header sits in exactly one file**, a plan already archived — hence the same archive exemption as the rule above, and for the same reason.

## The chantier number given twice

A number identifies a chantier for good: an archive written today must still resolve in six months, and nothing enforced it — the tracking doc holds the OPEN ones, archives the CLOSED ones.

🔴 **It had already broken twice, found by hand**: two July folders claim numbers the project later reassigned, and one number named a closed chantier and an open one at once. **It is read from the FIRST cell of a table row, never from prose** — a number in a sentence is a reference, not a claim to it.

⚠️ **Reading closed chantiers out of PROSE was written and dropped**: one archive sentence marks three OPEN chantiers as closed, another says a chantier *is not* closed. **What closed the gap is a declaration** — every archive folder now carries its numbers in its prefix, so the union is a folder listing, and `000` claims nothing. It found the two live reuses left: one certain, one whose number no archive ever wrote down.

## The FORM of a row, and of a task

A task opens on a mark and a `chantier.rank` number, then an **infinitive verb**; it holds **no link**, those living in the detail cell, and at most **72 characters** of bare text.
🔴 **72 is the commit-subject limit, and that is the whole reason it is 72** — a subject and a task are the same object, and `verify-commit-form` already caps one there. **The infinitive is the only binary substitute for "no retelling"**, which is a judgement and stays unarmed; an owner prefix is stripped first, `**Name** :` not being the verb.
⚠️ **The mark itself is a FILTER, never a rule read here**: a segment not opening on one is skipped whole, so a numbered task carrying no mark crosses everything above. Arming it keys on the `**N.M**` number, which a label never carries.

- **A row has FOUR columns**: one missing pipe desynchronises every field, and the task sitting past it is judged by nothing — lived on one row whose last task escaped every rule here.
- **An OPEN task holds no count.** "the 7 pitfalls" names a set that can be treated one at a time; "72 characters" is a threshold that cannot be split, and the definite article separates them. A ticked task keeps its count: what is done no longer goes stale.
- **The detail column carries a link, or the DASH saying there is nothing to point at yet** — a frozen chantier has no folder, and one invented to satisfy the rule reads as a folder something was lost from.
- **A stage folder is prefixed with its chantier number, three digits then `--`**, and holds at least one file. `000` where the number is impossible: the July archives predate the numbering, and a retroactive number would collide with one since reassigned.
- **Emptiness is asked of git, not of the disk** — a `.DS_Store` is invisible to a commit, and made an emptied folder look inhabited.
- **A `DETAILS.md` names only numbers the tracking doc still carries**, or a deleted task leaves a section reasoning nothing. Numbers are read from the START of a heading: further in, a number is a citation, `arXiv:2603.00539` having shown it.
- **That rule names the file, never "a file"**: a stage folder holds several, and it applies only where the prefix names an OPEN chantier — a side channel, a dead chantier and a pre-numbering folder carry none.
