#!/usr/bin/env bash
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
# unit a pull request reviews. Silent when there is nothing to compare (on the default branch, or
# in a fresh project with a single commit).
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
git rev-parse --verify --quiet "$base" >/dev/null || exit 0        # no remote ref: nothing to compare
here=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
[ "$here" = "${base#origin/}" ] && exit 0                          # on the default branch itself

merge_base=$(git merge-base "$base" HEAD 2>/dev/null || true)
[ -n "$merge_base" ] || exit 0
changed=$(git diff --name-only "$merge_base"...HEAD 2>/dev/null || true)
[ -n "$changed" ] || exit 0

# The two mechanical limbs of the rule, and nothing else.
visible=$(printf '%s\n' "$changed" | grep -E '^(templates/|docs/RUNBOOK\.md$)' || true)
# A shipped script appearing, disappearing OR CHANGING is visible: all three change what a
# project receives. Only the ones that TRAVEL count — an internal check of this repo alone is
# the refactor the rule deliberately leaves out.
scripts=$(git diff --name-only "$merge_base"...HEAD -- 'check.sh' 'open-pr.sh' 'init-project.sh' \
          'configure-repo.sh' 'checks/verify-tone.sh' 'checks/verify-narrative.sh' \
          'checks/verify-memories.sh' 2>/dev/null || true)
visible=$(printf '%s\n%s\n' "$visible" "$scripts" | grep -v '^$' || true)

[ -n "$visible" ] || { echo "✓ no user-visible change in this branch"; exit 0; }

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
