#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# Second person in versioned content (standard §1). Why it is written this way, and what the
# exceptions cost: docs/code/verify-tone.md
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/   # repo root, regardless of the caller's cwd

# The version, so the sweep that compares them all can see this one too.
if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

PRONOUNS='(you|your|yours|vous|votre|vos|tu|toi|ton|ta|tes)'   # tone-self
ALLOW='(2nd|second) person|2e personne|By contributing|wish to opt-out of having Renovate|# tone-self|# fr-pattern'

# -i applies to the PRONOUNS only: case-insensitive ALLOW would let a `# TONE-SELF` exempt a line.
raw=$(git grep -inIwE "$PRONOUNS" -- . ':(exclude)LICENSE*' ':(exclude)**/LICENSE*' 2>/dev/null || true)
hits=$(printf '%s' "$raw" | grep -vE "$ALLOW" || true)
exempt=$(printf '%s' "$raw" | grep -cE "$ALLOW" || true)

if [ -z "$hits" ]; then
  # A bare tick and a grep pointed at an empty tree read exactly alike.
  n=$(git grep -lI '' -- . 2>/dev/null | wc -l | tr -d ' ' || true)   # `|| true`: a repo with no text file makes git grep exit 1, and pipefail would kill this silently
  echo "✓ no second person in versioned content — read: $n text file(s), repo/ only (workspace/ is deliberately French), $exempt line(s) exempted by an ALLOW marker"
  exit 0
fi

printf '%s\n' "$hits" >&2
echo "✗ second person is forbidden in versioned content (standard §1)." >&2
echo "  Rewrite impersonally — \"the user\", or a turn of phrase without an addressee." >&2
echo "  A genuinely legitimate case is added to ALLOW in this script, with its reason." >&2
exit 1
