#!/usr/bin/env bash
# Composes a GitHub Release note on stdout: the text handed on stdin, then the two links it owes.
# Why the note is WRITTEN and not generated: docs/code/release-notes.md.
# Usage: ./release-notes.sh <tag> [previous-tag] < note.md > notes.md
# 🔴 Redirect, never `--notes-file <(…)`: process substitution DISCARDS the exit code, so a failure
# here would publish an EMPTY release body as a success.
# SHARED file: init-project.sh copies it into every generated project, like check.sh and open-pr.sh.
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

TAG="${1:?usage: release-notes.sh <tag> [previous-tag] < note.md}"
PREV="${2:-}"

# A runner already knows which repository it is in; asking gh there costs a call to learn it back.
REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner) \
    || { echo "release-notes: cannot read the repository from gh — aborting rather than printing half a note" >&2; exit 3; }
fi

# The written half arrives on stdin; absent, the note is its two links (.md note).
body=""
if [ ! -t 0 ]; then body=$(cat); fi
if [ -z "$body" ]; then
  echo "release-notes: no text on stdin — printing the links alone, to be completed by hand" >&2
fi

[ -n "$PREV" ] || PREV=$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || true)

if [ -n "$body" ]; then printf '%s\n\n' "$body"; fi

# 🔴 Pinned to the TAG, no anchor: the sealed heading leads the file, and a tagged file cannot rot.
printf '**What changed, entry by entry**: https://github.com/%s/blob/%s/CHANGELOG.md\n' "$REPO" "$TAG"
if [ -n "$PREV" ]; then
  printf '**Every commit in this version**: https://github.com/%s/compare/%s...%s\n' "$REPO" "$PREV" "$TAG"
else
  echo "release-notes: no previous tag found for ${TAG} — the commit link is omitted" >&2
fi
