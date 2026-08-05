#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A user-visible change without a CHANGELOG line.
#
# The rule (AGENTS.md): a line goes into `Unreleased` as soon as a change is visible TO WHOEVER
# USES THE REPO — "a template that changes, a RUNBOOK step that moves, a script's behaviour".
#
# Two of those three are PATHS, so two thirds of the rule are mechanical. Only the third is a
# judgement, and this check deliberately leaves it alone: an internal refactor stays out.
#
# 🔴 What it catches is the case that actually happened: four checks shipped, CHANGELOG untouched.
# Nobody notices a missing line — the file simply stays plausible.
#
# Compared against the merge base with the default branch, so the unit is the BRANCH, which is the
# unit a pull request reviews. When there is nothing to compare — on the default branch itself, or
# in a fresh project with no remote — it SAYS SO: a run that read nothing must not look like a run
# that found nothing.
#
# 🔴 WHAT COUNTS AS VISIBLE IS DETECTED, NEVER LISTED. This check travels into every generated
# project, where none of the paths below exist; a hand-kept list would then be a list of absent
# things, and would go on being read as a verdict. The paths are taken from what the repository
# actually holds, so the perimeter is whatever the place publishes — and nothing where it publishes
# nothing. A list of three shipped scripts sat here while ten travelled.
#
# The branch NAME was measured as a candidate trigger and rejected: 11 of this repository's last 40
# pull requests carry no CHANGELOG line and are right not to (docs, README, i18n, dependency bumps).
# A guard firing on better than one pull request in four is a guard that gets overridden by reflex.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# The perimeter, detected from what this repository actually holds. Empty is a legitimate answer,
# and the one every generated project gives.
published=()
[ -d templates ]        && published+=('^templates/')
[ -f docs/RUNBOOK.md ]  && published+=('^docs/RUNBOOK\.md$')
# The tooling a generated project receives — only meaningful where a generator exists to ship it.
# A check's behaviour changing IS visible to whoever runs it, and they all travel now.
[ -f init-project.sh ]  && published+=('^check\.sh$' '^open-pr\.sh$' '^checks/' '^init-project\.sh$' '^configure-repo\.sh$')

if [ "${#published[@]}" -eq 0 ]; then
  echo "  (nothing published from this repository is detectable here — no mechanical perimeter to check)"
  exit 0
fi

base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
git rev-parse --verify --quiet "$base" >/dev/null \
  || { echo "  (no $base to compare against — nothing to check)"; exit 0; }
here=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
if [ "$here" = "${base#origin/}" ]; then
  echo "  (on $here, the default branch itself — the unit compared is a branch, nothing to check)"
  exit 0
fi


merge_base=$(git merge-base "$base" HEAD 2>/dev/null || true)
[ -n "$merge_base" ] || { echo "  (no common ancestor with $base — nothing to compare)"; exit 0; }
changed=$(git diff --name-only "$merge_base"...HEAD 2>/dev/null || true)
[ -n "$changed" ] || { echo "✓ nothing changed since $base — no CHANGELOG line owed"; exit 0; }

visible=$(printf '%s\n' "$changed" | grep -E "$(IFS='|'; echo "${published[*]}")" || true)

[ -n "$visible" ] || { echo "✓ no user-visible change in this branch (perimeter: ${#published[@]} published path(s))"; exit 0; }

if printf '%s\n' "$changed" | grep -qx 'CHANGELOG.md'; then
  echo "✓ user-visible change, and CHANGELOG.md was updated"
  exit 0
fi

{
  echo "✗ user-visible change with no CHANGELOG.md line:"
  printf '    %s\n' $visible
  echo "  Add a line under 'Unreleased' saying what it MEANS for whoever uses the repo."
  echo "  An internal refactor does not belong there — but the paths above are not that."
} >&2
exit 1
