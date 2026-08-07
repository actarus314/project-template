# `checks/verify-changelog.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## A user-visible change with no CHANGELOG line

The rule is [`AGENTS.md`](../../AGENTS.md)'s. Two of its three examples are **paths**, so two
thirds of it are mechanical; the third is a judgement this check leaves alone.

🔴 What it catches is the case that happened: four checks shipped, `CHANGELOG` untouched. Nobody
notices a missing line — the file simply stays plausible.

## What counts as visible is DETECTED, never listed

This check travels into every generated project, where none of the paths it looks for exist: a
hand-kept list would be a list of **absent things**, still read as a verdict. The perimeter is
whatever the place publishes — and nothing where it publishes nothing. A list of three shipped
scripts sat here while ten travelled. Empty is a legitimate answer, and every generated project
gives it.

## The unit compared is the BRANCH

Compared against the merge base with the default branch — the unit a pull request reviews. With
nothing to compare *(the default branch itself, a fresh project with no remote)* it **says so**: a
run that read nothing must not look like one that found nothing.

🔴 **Three sources, not one: committed, staged, and neither.** Reading committed history alone made
the guard block *the very commit carrying the line it demanded* — the pre-commit hook runs before
that commit exists, so the fix and its verdict could never meet, and the only ways through were an
empty commit or `--no-verify`. A guard whose own remedy is unreachable teaches the bypass it exists
to prevent. In CI the last two sources are empty, so nothing there changes.

## What was measured and rejected

The branch **name** as a trigger: 11 of this repository's last 40 pull requests carry no CHANGELOG
line and are **right** not to (docs, README, i18n, dependency bumps). A guard firing on better than
one pull request in four is a guard overridden by reflex.

## One section of each type, and only the open one is judged

Keep a Changelog implies a single `### Added` per version and never says it, so nothing watched
it: **twelve cases over six published versions**, and two in the open section.

Only `Unreleased` is judged — **a published heading is not rewritten**. The published repeats are
**counted and printed**, never failed: a silent zero would read like a clean file.

The braces in `${dup_open}` are load-bearing. A bare `$name` followed by a multi-byte dash is read
as part of the variable name, and under `set -u` the check dies before its own message.
