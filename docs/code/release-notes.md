# `release-notes.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The Release owns nothing of its own

The rule is `METHODE.md`'s, in *"The four places a change is written"*: **a note nothing writes by hand is a note a script can produce, and reproduce identically.**

[Common Changelog](https://common-changelog.org/) asks that a release *"contain the same content as the changelog entry"*. **That is held by the LINK, never by a copy** — removed on a measurement: on 2026-08-14 the `v1.6.0` note ran to **10 606 characters**, saying the same thing twice in the same place.

## The one hand-written half, and it is not written here

A version opens on **at most three quoted lines** in `CHANGELOG.md`, and this script copies them verbatim above the list. **One source, copied mechanically** — the summary is never restated for the Release, which is what would let the two drift.

Three lines is the maintainer's objective: past that it stops being scannable, which is the only thing it is for. `verify-changelog.sh` refuses a fourth — unbounded, it would grow back into the copy that was just removed.

## Three depths, and this note carries only the top one

| Depth | Where it is read | For `v1.6.0` |
|---|---|---|
| the **pull request** | this note | 9 lines |
| the **entry** | `CHANGELOG.md`, linked | 44 lines |
| the **commit** | the compare link | every commit |

The list is GitHub's, grouped by `.github/release.yml`. **Its granularity is the pull request and cannot go lower** — hence two links rather than a longer note. Going from 44 entries to 9 lines is a REGROUPING: nothing is dropped, it moves one click away.

## 🔴 The changelog link points at the TAG, and carries no anchor

RUNBOOK §3 tags **before** sealing. At the instant this note is published there is no `## [X.Y.Z]` heading yet: the entries still sit under `Unreleased`, at the top of the file, so opening it at the tag lands on them.

An anchor would name a heading that does not exist yet; a link aimed at a branch would rot the day a heading changes — **silently, since no check reads a link living in a GitHub release rather than in a versioned file.** Pinning to the tag removes both risks: that file can never change again.

## A relabelled link, and a substitution that reports itself

GitHub ends its list with `**Full Changelog**:` followed by a *compare* URL — every commit, not the changelog. The label is replaced so each depth is named for what it is.
**A substitution that silently matches nothing is the failure mode**, so a missing label is reported on stderr and the note still goes out, in GitHub's own wording.

## Fail closed, and the two callers

If the API will not produce the list, the script aborts: **half a note published as a whole one is worse than no note**, nothing afterwards saying it was truncated.

It prints and decides nothing else, so the caller composes: the `release.yml` workflow adds nothing, `docker-publish.yml` puts the pinned **image reference first** — whoever self-hosts reads the release, not the workflow. **Only one of those two ever exists in a project** *(RUNBOOK §3)*; both on the same tag would race.
