#!/usr/bin/env bash
# Prints a GitHub Release note on stdout: GitHub's pull-request list, then the links to the two
# depths below it. Why it copies the CHANGELOG nowhere: docs/code/release-notes.md.

# Usage: ./release-notes.sh <tag> [previous-tag] > notes.md
# 🔴 Redirect, never `--notes-file <(…)`: process substitution DISCARDS the exit code, so a failure
# here would publish an EMPTY release body as a success.
# SHARED file: init-project.sh copies it into every generated project, like check.sh and open-pr.sh.
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

TAG="${1:?usage: release-notes.sh <tag> [previous-tag]}"
PREV="${2:-}"

# A runner already knows which repository it is in; asking gh there costs a call to learn it back.
REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner) \
    || { echo "release-notes: cannot read the repository from gh — aborting rather than printing half a note" >&2; exit 3; }
fi

# The three-line summary the CHANGELOG carries for this version, and the ONLY hand-written half of
# this note. Read from there, never restated here: one source, copied mechanically (.md note).
summary=""
if [ -f CHANGELOG.md ]; then
  read_summary() { awk -v v="$1" '
      $0 ~ "^## \\[" v "\\]" {in_v=1; next}
      in_v && /^(## |### )/ {exit}
      in_v && /^> / {sub(/^> /, ""); print}' CHANGELOG.md; }
  # At tag time the section is still `Unreleased` — RUNBOOK §3 tags before sealing.
  summary=$(read_summary "${TAG#v}")
  [ -n "$summary" ] || summary=$(read_summary "Unreleased")
fi

args=(-f "tag_name=$TAG")
[ -n "$PREV" ] && args+=(-f "previous_tag_name=$PREV")
generated=$(gh api --method POST "repos/$REPO/releases/generate-notes" "${args[@]}" --jq .body) \
  || { echo "release-notes: GitHub would not generate the pull-request list for $TAG — aborting" >&2; exit 3; }

# That label names the compare link a changelog, which it is not: it is every commit.
COMPARE_LABEL='**Full Changelog**:'
case "$generated" in
  *"$COMPARE_LABEL"*) generated=${generated/"$COMPARE_LABEL"/**Every commit in this version**:} ;;
  *) echo "release-notes: GitHub no longer labels the compare link '${COMPARE_LABEL}' — left as it came" >&2 ;;
esac

if [ -n "$summary" ]; then printf '%s\n\n' "$summary"; fi
printf '%s\n' "$generated"

# 🔴 Pinned to the TAG, and no anchor: at that point the entries are still under `Unreleased` (.md note).
if [ -f CHANGELOG.md ]; then
  printf '\n**What changed, entry by entry**: https://github.com/%s/blob/%s/CHANGELOG.md\n' "$REPO" "$TAG"
fi
