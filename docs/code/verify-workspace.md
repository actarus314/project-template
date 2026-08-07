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

An absent neighbour and a clean neighbour produce the very same empty output. That is said out loud in the script rather than left to a mute exit, because this is the one check whose entire reason to exist is that nothing else looks over there — a silent no-op here would read exactly like "nothing to see" whether or not `../workspace` exists at all.

## A tracked NAME betrays, not the content

Why a filename is enough to flag, and what gitleaks is structurally unable to see, belongs to [`verify-secret-blindspots.md`](verify-secret-blindspots.md) — it is that check's subject. Here it is applied to one place gitleaks never reaches at all: the neighbouring repository.

## ONE tracking system, not one file

The rule — one tracking system, whichever it is — is `METHODE.md`'s to state. Counting only files named `SUIVI|TRACKING|PROGRESS.md` was blind to the collision METHODE actually forbids: a `.planning/` directory sitting beside a `SUIVI.md` is two systems for one question, and it is the stale one that gets read first. Measured: such a workspace returned the same "1 tracking doc" as one holding nothing else at all — the count had to become a count of *systems*, not of files.

**The `OTHERS` list cannot be complete** — no check can know every tracking tool that exists. So it is named in the verdict: whoever reads it sees what was looked for, and therefore what was not.

**What the named list still cannot see**: every tracked top-level dot-directory, minus the editor and forge ones. Those are NAMED in `unlisted`, never counted as a fault by themselves — treating an unknown directory as a tracking system on sight would fire on the next editor or tool that ships one, and a guard that fires where it should not earns its own override. The path is filtered on `/`
first because a tracked path holding a slash has a directory as its head, which is cheaper and more honest than testing the disk for a directory git tracks but the worktree happens not to hold.

## Backlog hygiene: a form, not a state

METHODE's rule — the backlog holds OPEN work only, a closed item leaves for the state section or an archive — is written in the tracking doc itself, because closure markers had once piled up inside the backlog until it stopped answering "where do I put the effort".

It was broken again the same day, four markers deep, and no check noticed at the time: growth was measured at **+24 % against a 25 % threshold** — one point short — but growth is the SYMPTOM, not the rule. The rule itself is binary (a closed marker inside the open-work section), so it needs no threshold and no measure of its own. This is the shape a closing pass leaves behind when only its first half was done.

⚠️ **What this cannot do, and must not be read as more than.** It matches a FORM, never a state: an item that is finished, left in place, and never marked at all is invisible to it. The marker is a habit of whoever writes the document, not a guarantee, and a check rested on a habit inherits that habit's reliability. Whether the backlog still describes the open work is the same question as whether the tracking doc is TRUE, which this whole file states is not verifiable.

🔴 **The marker counts only at the START of a cell.** Anywhere else it is a MENTION, not a mark:
the very row describing this rule quotes `des lignes passent à ✅`, and a loose match once read that sentence itself as a closed item. The same failure the forbidden-command hook pays for with heredocs, and the wiring check pays for with code lines — a literal appears in prose too.
