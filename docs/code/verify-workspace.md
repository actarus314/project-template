# `checks/verify-workspace.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why this check exists at all

Why `workspace/` has no remote, and what that buys `repo/`, is stated once, in `AGENTS.md`.

What that same property costs: it makes `workspace/` invisible to every other control — no remote means no diff-vs-origin, no CI, no pull request — and `check.sh` runs inside `repo/`
without ever looking beside it. This was missed **four times** for exactly that reason before this check existed.

What is mechanically verifiable, and only that: it exists and is a git repository (a plain folder loses everything on a bad `rm`); it has NO remote — the hard constraint that protects `repo/`;
nothing named like a secret is tracked; a single tracking document.

⚠️ NOT verifiable, and never to be promised: whether what the tracking document **says** is true.

## Silence is a choice, not an accident

An absent neighbour and a clean neighbour produce the very same empty output. The script says so rather than exiting mute: nothing else looks over there, so a silent no-op reads as "nothing to see" either way.

## A tracked NAME betrays, not the content

Why a filename is enough to flag, and what gitleaks is structurally unable to see, belongs to [`verify-secret-blindspots.md`](verify-secret-blindspots.md) — it is that check's subject. Here it is applied to one place gitleaks never reaches at all: the neighbouring repository.

## ONE tracking system, not one file

The rule — one tracking system, whichever it is — is `METHODE.md`'s to state. Counting only files named `SUIVI|TRACKING|PROGRESS.md` was blind to the collision METHODE actually forbids: a `.planning/` directory sitting beside a `SUIVI.md` is two systems for one question, and it is the stale one that gets read first. Measured: such a workspace returned the same "1 tracking doc" as one holding nothing else at all — the count had to become a count of *systems*, not of files.

**The `OTHERS` list cannot be complete** — no check can know every tracking tool that exists. So it is named in the verdict: whoever reads it sees what was looked for, and therefore what was not.

**What the named list still cannot see**: every tracked top-level dot-directory, minus the editor and forge ones. Those are NAMED in `unlisted`, never counted as a fault by themselves — treating an unknown directory as a tracking system on sight would fire on the next editor or tool that ships one, and a guard that fires where it should not earns its own override.

## Backlog hygiene: a form, not a state

METHODE's rule — the backlog holds OPEN work only, a closed item leaves for the state section or an archive — is written in the tracking doc itself, because closure markers had once piled up inside the backlog until it stopped answering "where do I put the effort".

It broke again the same day, four markers deep, unseen: growth read **+24 % against a 25 % threshold**, one point short — but growth is the SYMPTOM. The rule is binary (a closed marker inside the open-work section), so it needs no threshold at all. It is the shape a closing pass leaves when only its first half was done.

⚠️ **What this cannot do, and must not be read as more than.** It matches a FORM, never a state: an item that is finished, left in place, and never marked at all is invisible to it. The marker is a habit, not a guarantee, and a check rested on a habit inherits its reliability.

## The other direction: open work living OUTSIDE the tracking doc

Splitting the tracking doc into neighbours recreates the separate backlog METHODE forbids, the moment one of them holds an action. The hygiene above never asked: it opens the tracking doc alone, looking for a CLOSED item.

**A file DECLARES it holds none**, with `<!-- no-open-work -->`, and only declared files are read. A name would be wrong twice over: METHODE makes those names a default, and the conformity checklist beside them legitimately carries **58 empty boxes**.

**A closing archive is read while still uncommitted** — the moment an action gets buried, and the only one worth looking at: an archive is immutable, so a committed one can never be repaired. Ten of the thirty already hold the pattern.

🔴 **The pattern is narrow because the wide one was measured**: anything resembling an action returned **7 hits for 1 real leftover**, the other six being the rule quoting itself. Only a leftover that declares itself matches. 

🔴 **The marker counts only at the START of a cell.** Anywhere else it is a MENTION, not a mark:
the very row describing this rule quotes `des lignes passent à ✅`, and a loose match once read that sentence itself as a closed item. The same failure the forbidden-command hook pays for with heredocs, and the wiring check pays for with code lines — a literal appears in prose too.

## The chantier number given twice

A number identifies a chantier for good: an archive or a merged pull request written today must still resolve to the same work in six months. Nothing enforced it — the tracking doc holds the OPEN ones, the archives the CLOSED ones, and no place holds the union, so the rule ran on discipline, which METHODE says never holds.

🔴 **It had already broken twice, and by hand.** Two July folders call themselves chantiers 2 and 3, both numbers handed out again on 2026-08-05. A third was live: 13 named a chantier closed on 05/08 **and** an open one restored on 08/08, the restoration re-taking a number freed three days earlier.

**The number is read from the FIRST cell of a table row, never from prose** — a number in a sentence is a reference, not a claim to it.

⚠️ **It compares OPEN rows to each other, and nothing else — the verdict says `duplicates only`, so the limit travels with the count.** Extending it to closed chantiers was written and dropped: an archive states its coverage in prose, and the one form that reads as a list is not one.
Taken literally, one such sentence marks three OPEN chantiers as closed, and another says a chantier *is not* closed — which a loose pattern reads backwards. **The case that actually happened stays invisible to it, and saying so beats a pattern firing on the wrong rows.**

➡️ **What would close the gap is a declaration, not a cleverer pattern** — an archive stating its chantiers in a field, the way a check declares `# blocking:`. Until then this half catches two live rows colliding, and the hard case stays a reading.
