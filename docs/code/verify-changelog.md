# `checks/verify-changelog.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## A user-visible change with no CHANGELOG line

The rule ([`AGENTS.md`](../../AGENTS.md)): a line goes into `Unreleased` as soon as a change is
visible **to whoever uses the repo** — "a template that changes, a RUNBOOK step that moves, a
script's behaviour".

Two of those three are **paths**, so two thirds of the rule are mechanical. Only the third is a
judgement, and this check deliberately leaves it alone: an internal refactor stays out.

🔴 What it catches is the case that actually happened: four checks shipped, `CHANGELOG` untouched.
Nobody notices a missing line — the file simply stays plausible.

## What counts as visible is DETECTED, never listed

This check travels into every generated project, where none of the paths it looks for exist. A
hand-kept list would then be a list of **absent things**, and would go on being read as a verdict.
The paths are taken from what the repository actually holds, so the perimeter is whatever the place
publishes — and nothing where it publishes nothing. A list of three shipped scripts sat here while
ten travelled.

Empty is a legitimate answer, and the one every generated project gives.

## The unit compared is the BRANCH

Compared against the merge base with the default branch, because that is the unit a pull request
reviews. When there is nothing to compare — on the default branch itself, or in a fresh project with
no remote — it **says so**: a run that read nothing must not look like a run that found nothing.

🔴 **Three sources, not one: committed, staged, and neither.** Reading committed history alone made
the guard block *the very commit carrying the line it demanded* — the pre-commit hook runs before
that commit exists, so the fix and its verdict could never meet, and the only ways through were an
empty commit or `--no-verify`. A guard whose own remedy is unreachable teaches the bypass it exists
to prevent. In CI the last two sources are empty, so nothing there changes.

## What was measured and rejected

The branch **name** as a trigger: 11 of this repository's last 40 pull requests carry no CHANGELOG
line and are **right** not to (docs, README, i18n, dependency bumps). A guard firing on better than
one pull request in four is a guard overridden by reflex.
