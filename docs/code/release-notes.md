# `release-notes.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why a script exists at all

The rule is `METHODE.md`'s, in *"The four places a change is written"*: the Release owns **nothing of its own**.
What follows from it for this file: **a note nothing writes by hand is a note a script can produce, and reproduce identically** — which is the only reason one exists here.

The source it rests on is [Common Changelog](https://common-changelog.org/): a release *"should contain the same content as the changelog entry"*, and *"long descriptions should be in commits or other references"*. A hand-written Release is a third rendering of one change, and nothing can check a third rendering against the other two.

## 🔴 The tag comes first, so the section is still called `Unreleased`

RUNBOOK §3 tags **before** sealing, and that order is not negotiable: sealing first makes `verify-version.sh` red, and the sealing pull request unmergeable.
A release workflow fires on the tag push — **at that instant `CHANGELOG.md` has no `## [X.Y.Z]` heading at all.**

➡️ So the extraction falls back to `Unreleased`, and says so on stderr.
Sealing renames the heading; it does not touch the block underneath, which is why the two readings return the same text.
**Demanding the sealed heading would have refused every note at the one moment it is asked for** — found by running it, not by reading it.

## Fail closed, and what that costs

A missing half is an error, never a shorter note.
The block is the half that says what the version *means*; the list is the half a reader uses to find the change. **Half a note published as a whole one is worse than no note**, because nothing afterwards says it was truncated.

`GITHUB_REPOSITORY` is preferred over `gh repo view`: a runner already knows which repository it is in, and asking the API to learn it back is a network call per release.

## Two callers, one output on stdout

The script prints and decides nothing else, so the caller composes:

| Caller | What it puts around the note |
|---|---|
| the `release.yml` workflow | nothing — the note is the whole body |
| the `docker-publish.yml` workflow | the pinned **image reference first**, since whoever self-hosts reads the release rather than the workflow |

**Only one of those two workflows ever exists in a project** *(RUNBOOK §3)*; both starting on the same tag would race.

The heading is dropped from the block: the Release already carries the version as its title, and repeating it is the drift being removed.
