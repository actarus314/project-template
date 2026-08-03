#!/usr/bin/env bash
# Second person in versioned content — forbidden by the standard (§1) and by the AGENTS.md of every
# generated project. Until this script existed, NOTHING verified it: the rule held by discipline
# alone, and that is how it reached nine files, four of them templates copied into every project
# this repo generates.
#
# Shared, like verify-version.sh: called by ./check.sh AND by the CI, so the rule lives in ONE
# place. A copy of this grep inside a workflow would be a second source, and two sources drift.
#
# ⚠ `git grep` on purpose, never a filesystem walk: the rule is about what is COMMITTED. An
#   untracked scratch file breaking it is nobody's business.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/   # repo root, regardless of the caller's cwd

# Exceptions are LISTED and NARROW — never a disabled rule, so a real slip inside an exempted file
# is still caught (the principle the standard states for gitleaks fingerprints, §18):
#   · licenses     — third-party verbatim text, not ours to reword;
#   · the RULE     — the lines that STATE the rule have to spell the forbidden words out;
#   · contributing — the "By contributing…" clause, addressed to the contributor by design;
#   · a quotation  — foreign documentation quoted verbatim loses its value reworded;
#   · tone-self    — the line below, which has to carry the very words it hunts for.
PRONOUNS='(you|your|yours|vous|votre|vos|tu|toi|ton|ta|tes)'   # tone-self
ALLOW='(2nd|second) person|2e personne|By contributing|wish to opt-out of having Renovate|# tone-self'

hits=$(git grep -nIwE "$PRONOUNS" -- . ':(exclude)LICENSE*' ':(exclude)**/LICENSE*' 2>/dev/null \
       | grep -vE "$ALLOW" || true)

if [ -z "$hits" ]; then
  echo "✓ no second person in versioned content"
  exit 0
fi

printf '%s\n' "$hits" >&2
echo "✗ second person is forbidden in versioned content (standard §1)." >&2
echo "  Rewrite impersonally — \"the user\", or a turn of phrase without an addressee." >&2
echo "  A genuinely legitimate case is added to ALLOW in this script, with its reason." >&2
exit 1
