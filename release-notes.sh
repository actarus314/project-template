#!/usr/bin/env bash
# Prints a GitHub Release note on stdout: the version's CHANGELOG block, then the auto-generated
# pull-request list. Why it is generated rather than written: docs/code/release-notes.md.

# Usage: ./release-notes.sh <tag> [previous-tag]
#        gh release create vX.Y.Z --title vX.Y.Z --notes-file <(./release-notes.sh vX.Y.Z)

# SHARED file: init-project.sh copies it into every generated project, like check.sh and open-pr.sh.
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

TAG="${1:?usage: release-notes.sh <tag> [previous-tag]}"
PREV="${2:-}"
VERSION="${TAG#v}"

[ -f CHANGELOG.md ] || { echo "release-notes: no CHANGELOG.md here — nothing to copy" >&2; exit 2; }

# Heading excluded: the Release already carries the version as its title.
extract() {   # <heading-content>
  awk -v v="$1" '
    $0 ~ "^## \\[" v "\\]" {inblock=1; next}
    inblock && /^## / {exit}
    inblock {print}' CHANGELOG.md |
  # Leading and trailing blank lines only; the block's own shape is left alone.
  sed -e '/./,$!d' | awk 'NF {p=NR} {l[NR]=$0} END {for (i=1; i<=p; i++) print l[i]}'
}

block=$(extract "$VERSION")
# 🔴 THE TAG COMES FIRST, THE SEALING SECOND (RUNBOOK §3): at tag time this section is still called
# `Unreleased`, and sealing renames the heading without touching the block.
if [ -z "$block" ]; then
  block=$(extract "Unreleased")
  [ -n "$block" ] && echo "release-notes: no sealed '## [${VERSION}]' yet — reading 'Unreleased', which is this version's block until the sealing renames it." >&2
fi

if [ -z "$block" ]; then
  echo "release-notes: CHANGELOG.md has neither a '## [${VERSION}]' section nor a non-empty 'Unreleased'." >&2
  echo "  There is nothing to say about this version that the pull-request list does not already say." >&2
  exit 1
fi

# A runner already knows which repository it is in; asking gh there costs a call to learn it back.
REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner) \
    || { echo "release-notes: cannot read the repository from gh — aborting rather than printing half a note" >&2; exit 3; }
fi

args=(-f "tag_name=$TAG")
[ -n "$PREV" ] && args+=(-f "previous_tag_name=$PREV")
generated=$(gh api --method POST "repos/$REPO/releases/generate-notes" "${args[@]}" --jq .body) \
  || { echo "release-notes: GitHub would not generate the pull-request list for $TAG — aborting" >&2; exit 3; }

printf '%s\n\n%s\n' "$block" "$generated"
