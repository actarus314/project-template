#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A user-visible change without a CHANGELOG line — the case that happened: four checks shipped,
# CHANGELOG untouched, and a missing line leaves the file perfectly plausible.
# The perimeter is DETECTED, never listed: this travels where none of these paths exist.
# The rule, the three diff sources, and what was measured and rejected: docs/code/verify-changelog.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# ── One `###` of each type per version, and the open section is the one that can still be fixed ──
# Keep a Changelog implies it without ever saying it, so it was drifting unwatched. Only
# `Unreleased` is judged: a published heading is not rewritten (why: docs/code/verify-changelog.md).
# The published ones are COUNTED and said out loud — a silent zero would read like a clean file.
if [ -f CHANGELOG.md ]; then
  dup_open=$(awk '/^## \[Unreleased\]/ {o=1; next} /^## \[/ {o=0} o && /^### / {c[$2]++}
                  END {for (k in c) if (c[k] > 1) printf "%s x%d ", k, c[k]}' CHANGELOG.md || true)
  dup_pub=$(awk '/^## \[/ {v=($0 ~ /Unreleased/) ? "" : $0} v && /^### / {c[v FS $2]++}
                 END {n=0; for (k in c) if (c[k] > 1) n++; print n+0}' CHANGELOG.md || true)
  if [ -n "$dup_open" ]; then
    # Braces are load-bearing: a bare $name followed by a multi-byte dash is read as part of the name.
    echo "✗ CHANGELOG 'Unreleased' repeats a section: ${dup_open}— Keep a Changelog wants one of each" >&2
    echo "  Merge them: one ### per type, in the order Added / Changed / Deprecated / Removed / Fixed / Security." >&2
    exit 1
  fi
  echo "  (Unreleased: one section per type · ${dup_pub} published version(s) repeat one — not judged, they are sealed)"
fi

published=()
[ -d templates ]        && published+=('^templates/')
[ -f docs/RUNBOOK.md ]  && published+=('^docs/RUNBOOK\.md$')
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
# THREE sources — committed, staged, neither. Why: docs/code/verify-changelog.md.
changed=$({ git diff --name-only "$merge_base"...HEAD
            git diff --name-only --cached
            git diff --name-only; } 2>/dev/null | sort -u || true)
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
