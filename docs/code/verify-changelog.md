# `checks/verify-changelog.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## A user-visible change with no CHANGELOG line

The rule is [`AGENTS.md`](../../AGENTS.md)'s. Two of its three examples are **paths**, so two thirds
of it are mechanical; the third is a judgement this check leaves alone. 🔴 What it catches is the
case that happened: four checks shipped, `CHANGELOG` untouched — nobody notices a missing line.

## What counts as visible is DETECTED, never listed

This check travels into every generated project, where none of the paths it looks for exist: a
hand-kept list would be a list of **absent things**, still read as a verdict. The perimeter is
whatever the place publishes. A list of three shipped scripts sat here while ten travelled, and
empty is a legitimate answer.

## The unit compared is the BRANCH

Compared against the merge base with the default branch — the unit a pull request reviews. With
nothing to compare *(the default branch itself, a fresh project with no remote)* it **says so**: a
run that read nothing must not look like one that found nothing.

🔴 **Three sources, not one: committed, staged, and neither.** Reading committed history alone made
the guard block *the very commit carrying the line it demanded*, so the fix and its verdict could
never meet — a guard whose own remedy is unreachable teaches the bypass it exists to prevent. In CI
the last two sources are empty.

## What was measured and rejected

The branch **name** as a trigger: 11 of the last 40 pull requests carry no CHANGELOG line and are
**right** not to. A guard firing on one pull request in four is a guard overridden by reflex.

## The form, and why only the open section is judged

Keep a Changelog implies a single `### Added` per version and never says it: **twelve cases over six
published versions**. The size ceiling is **750 characters per entry**, the third quartile of the
file's own 185 *(median 507)*.
⚠️ That calibration is **weak by construction** — a threshold taken from the corpus it means to
reform endorses the drift. External guides say one line, or one to three sentences.

Only `Unreleased` is judged for those two — **a published entry is not rewritten**. The sealed ones
are **counted and printed**: a silent zero would read like a clean file.

The **inline Release link** is checked on every heading, sealed ones included: it belongs to the
heading rather than to the entry, and sealing is a manual gesture — which is how five of six
releases shipped without it.

⚠️ **Only the countable part is gated.** Concision itself is written in — `METHODE` states that no
script reads clarity, and a model blocking on it is worse than nothing.

The braces in `${dup_open}` are load-bearing: a bare `$name` before a multi-byte dash is read as
part of the name, and under `set -u` the check dies before its own message.
