#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   (what this does with a verdict; compared to the control table AND to its real exit code)
# Names that must not appear in a PUBLIC repository — private project names, hosts, people. gitleaks
# reads token SHAPES and is blind to these by construction. Why the list lives outside the repo, and
# how to word an entry: docs/code/verify-private-names.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# The list NEVER lives in the repository it protects: publishing the names to hide would defeat it.
LIST="${PRIVATE_NAMES_FILE:-../workspace/private-names.txt}"

if [ ! -f "$LIST" ]; then
  # Said out loud, never silent: no list reads exactly like a clean sweep otherwise.
  echo "  (no $LIST beside this repo — nothing was read)"
  exit 0
fi

# Comments and blank lines dropped; everything else is an extended-regex alternative.
# `|| true` is load-bearing: a comments-only list is the SHIPPED template (why: the note).
patterns=$(grep -vE '^\s*(#|$)' "$LIST" | paste -sd'|' - || true)
if [ -z "$patterns" ]; then
  echo "  ($LIST is empty — nothing was read)"
  exit 0
fi

count=$(grep -vE '^\s*(#|$)' "$LIST" | wc -l | tr -d ' ' || true)
hits=$(git ls-files -z | xargs -0 grep -niE "$patterns" 2>/dev/null || true)

if [ -n "$hits" ]; then
  echo "✗ a private name appears in versioned content — this repository is PUBLIC:" >&2
  printf '%s\n' "$hits" | head -20 >&2
  echo "  Replace it with a placeholder. ⚠️ Rewriting the file does NOT remove it from the" >&2
  echo "  history already published — that decision belongs to the maintainer." >&2
  exit 1
fi

echo "✓ no private name in versioned content — read: $count pattern(s) from $LIST"
