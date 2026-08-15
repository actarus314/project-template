# `release-notes.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The Release is WRITTEN — the script only adds what is mechanical

A Release note is a short opening paragraph, the highlights, and two links. **The first two cannot be generated**: they are a judgement about what a version is worth, and no list of titles stands in for them.

So this script takes the written half on **stdin** and appends the half that is mechanical. It composes; it does not compose *for* anyone.

## What was tried, and why it was dropped

**Copying the version's CHANGELOG block into the note.** Measured on 2026-08-14: the `v1.6.0` note ran to **10 606 characters** — the block, then GitHub's pull-request list, the same period said twice in one place.

**Replacing it with GitHub's pull-request list alone.** Shorter, and worse: 9 titles say less than one paragraph, and the titles were written for reviewers rather than for whoever reads a release. `.github/release.yml` grouped that list by label; with the list gone, it had nothing left to group and was deleted.

**Three quoted lines opening each version in the changelog**, copied into the note. It kept the changelog as the single source, but it put a second register into a file that has one, and the note still could not introduce anything.

➡️ What survives is the shape `v1.4.0` already had by hand: a paragraph, the highlights, the links.

## 🔴 The changelog link points at the TAG, and carries no anchor

RUNBOOK §3 seals **before** tagging, so at the instant a note is published the heading `## [X.Y.Z]` exists and leads the file. The bare link lands on it either way — which is why the inversion changed nothing here, only the reason.

The anchor stays off for the reason that outlived the order: one aimed at a branch would rot the day a heading changes — **silently, since no check reads a link that lives in a release rather than in a versioned file.** Pinned to the tag, the file can never change again, so the link cannot rot at all.

## Empty stdin prints the links alone, and says so

A caller with no text to give gives none — the `release.yml` workflow fires on a tag push and has nothing to write. It then publishes the two links, **and the note is completed by hand.**

That is deliberate: filling the gap with a generated list would produce a note that looks finished and says nothing. The script warns on stderr rather than staying silent about it.

## The previous tag, and the two callers

Absent, the previous tag is read from `git describe` on the tag's parent — the compare link is dropped, with a warning, when there is none.

The script prints and decides nothing else, so the caller composes: `release.yml` adds nothing, `docker-publish.yml` puts the pinned **image reference first** — whoever self-hosts reads the release, not the workflow. **Only one of the two ever exists** *(RUNBOOK §3)*; both on one tag would race.
