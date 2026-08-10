#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A sentence cut across two lines: a width frozen into the file, which the renderer undoes anyway.
# The rule is METHODE's — one sentence per line. Why a width threshold was rejected instead, and
# what this ignores and why: docs/code/verify-line-form.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# Third-party texts keep the upstream's own layout: reformatting makes them uncomparable to it.
THIRD_PARTY='CODE_OF_CONDUCT\.md$|LICENSE|/vendor/'

mapfile -t files < <(git ls-files '*.md' | grep -Ev "$THIRD_PARTY" || true)
skipped=$(git ls-files '*.md' | grep -Ec "$THIRD_PARTY" || true)

if [ "${#files[@]}" -eq 0 ]; then
  echo "  (no versioned .md here — nothing to read)"
  exit 0
fi

hits=$(awk '
  FNR==1 {fence=0; comment=0; fm=0; prev=""}
  {
    line=$0; sub(/^[[:space:]]+/,"",line); sub(/[[:space:]]+$/,"",line)
    gsub(/^(>[[:space:]]*)+/, "", line)   # stripped first: a fence or a comment stays one inside a quote too
  }
  # A YAML front matter is a set of KEYS, not prose: `name:` and `description:` are two records, and
  # reading them as one sentence cut in half would refuse the only shape a SKILL.md may have.
  FNR==1 && line ~ /^---$/ {fm=1; next}
  fm { if (line ~ /^---$/) fm=0; prev=""; next }
  line ~ /^```/ {fence=!fence; prev=""; next}
  fence {next}
  comment { if (line ~ /-->/) comment=0; prev=""; next }
  line ~ /^<!--/ {
    if (line !~ /-->/) comment=1   # opens here, closes on a LATER line — everything between is content, not prose
    prev=""; next
  }
  {
    # None of these can be the tail of the line above, so the sentence before them is complete:
    # a blank line, a heading, a table row, a bullet, a horizontal rule.
    if (line == "" || line ~ /^#/ || line ~ /^\|/ || line ~ /^-{3,}$/ \
        || line ~ /^([-*+]|[0-9]+[.)])[[:space:]]/) { prev=""; next }
    if (prev != "") printf "%s:%d: %s\n", FILENAME, FNR-1, substr(prev, length(prev)-52)
    # A line ENDS a sentence when it closes on punctuation, on emphasis, or on a code span.
    prev = (line ~ /([.!?:;)]|\*\*|[*_`])[[:space:]]*$/) ? "" : line
  }
  END {prev=""}
' "${files[@]}" || true)

n=$(printf '%s' "$hits" | grep -c . || true)
if [ "$n" -gt 0 ]; then
  {
    echo "✗ a sentence is cut across two lines, in ${n} place(s) — the line break must follow the sentence:"
    printf '%s\n' "$hits" | head -12 | sed 's/^/    /'
    [ "$n" -gt 12 ] && echo "    … and $((n - 12)) more"
    echo "  Wrapping at a column freezes a width the renderer undoes anyway. One sentence, one line."
  } >&2
  exit 1
fi

echo "✓ every line break follows a sentence — read: ${#files[@]} versioned .md file(s), ${skipped} third-party text(s) left alone"
