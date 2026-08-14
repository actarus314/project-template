# `release-notes.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The Release owns nothing of its own

The rule is `METHODE.md`'s, in *"The four places a change is written"*: **a note nothing writes by hand is a note a script can reproduce identically.**

[Common Changelog](https://common-changelog.org/) asks that a release *"contain the same content as the changelog entry"*. **That is held by the LINK, never by a copy** — removed on a measurement: the `v1.6.0` note ran to **10 606 characters**, saying the same thing twice in one place.

## The one hand-written half, and it is not written here

A version opens on **at most three quoted lines** in `CHANGELOG.md`, and this script copies them verbatim above the list. **One source, copied mechanically** — the summary is never restated for the Release, which is what would let the two drift.

Three lines is the maintainer's objective: past that it stops being scannable, which is the only thing it is for. `verify-changelog.sh` refuses a fourth — unbounded, it would grow back into the copy that was just removed.

🔴 **Which section is read turns on whether a heading EXISTS, never on whether it is empty** — an empty fallback staples today's summary onto an old version being regenerated, which is how the first cut of this shipped.

## Three depths, and this note carries only the top one

| Depth | Where it is read | For `v1.6.0` |
|---|---|---|
| the **pull request** | this note | 9 lines |
| the **entry** | `CHANGELOG.md`, linked | 44 lines |
| the **commit** | the compare link | every commit |

The list is GitHub's, grouped by `.github/release.yml`. **Its granularity is the pull request and cannot go lower** — hence two links rather than a longer note. 44 entries becoming 9 lines is a REGROUPING: nothing is dropped, it moves one click away.

## 🔴 The changelog link points at the TAG, and carries no anchor

RUNBOOK §3 tags **before** sealing. At the instant this note is published there is no `## [X.Y.Z]` heading yet: the entries still sit under `Unreleased`, at the top of the file, so opening it at the tag lands on them.

An anchor would name a heading that does not exist yet; one aimed at a branch would rot the day a heading changes — **silently, no check reading a link that lives in a release rather than a versioned file.** Pinned to the tag, that file can never change again.

## A relabelled link, and fail closed

GitHub ends its list with `**Full Changelog**:` on a *compare* URL — every commit, not the changelog — so the label is replaced. **A substitution silently matching nothing is the failure mode**, so a missing label is reported on stderr and the note still ships in GitHub's wording.

If the API will not produce the list, the script aborts: **half a note published as a whole one is worse than no note**, nothing afterwards saying it was truncated.

It prints and decides nothing else, so the caller composes: `release.yml` adds nothing, `docker-publish.yml` puts the pinned **image reference first** — whoever self-hosts reads the release, not the workflow. **Only one of the two ever exists** *(RUNBOOK §3)*; both on one tag would race.
