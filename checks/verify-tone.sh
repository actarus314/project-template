#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
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

# The version, so the sweep that compares them all can see this one too.
if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# Exceptions are LISTED and NARROW — never a disabled rule, so a real slip inside an exempted file
# is still caught (the principle the standard states for gitleaks fingerprints, §18):
#   · licenses     — third-party verbatim text, not ours to reword;
#   · the RULE     — the lines that STATE the rule have to spell the forbidden words out;
#   · contributing — the "By contributing…" clause, addressed to the contributor by design;
#   · a quotation  — foreign documentation quoted verbatim loses its value reworded;
#   · tone-self    — the line below, which has to carry the very words it hunts for;
#   · fr-pattern   — a regex that must MATCH French prose. `grep -w` treats an accent as a word
#                    boundary, so `obsolètes` splits into `obsol` and `tes`, and `tes` is a pronoun   # tone-self
#                    on this very list. The hit is an artefact of the splitting, not a second
#                    person — the same accent blindness that elsewhere makes a French sweep
#                    under-count. Marked line by line, never file-wide.
PRONOUNS='(you|your|yours|vous|votre|vos|tu|toi|ton|ta|tes)'   # tone-self
ALLOW='(2nd|second) person|2e personne|By contributing|wish to opt-out of having Renovate|# tone-self|# fr-pattern'

# -i, and it is not cosmetic: `git grep` is case-sensitive, so the capitalised forms went through
# untouched — the second person at the START of a sentence, which is where it lands most often.   # tone-self
# The repo held none in prose, so the guard never had the chance to give itself away; the flag
# found one on the first run, in a workflow template copied into every generic project.
#
# The -i stops at the PRONOUNS. ALLOW carries line markers (`# tone-self`) and literal quotations,
# and matching those case-insensitively would widen the only exception mechanism this script has —
# a `# TONE-SELF` would exempt a line. The defect was in the pronouns; the exceptions keep their
# original precision.
hits=$(git grep -inIwE "$PRONOUNS" -- . ':(exclude)LICENSE*' ':(exclude)**/LICENSE*' 2>/dev/null \
       | grep -vE "$ALLOW" || true)

if [ -z "$hits" ]; then
  # Counted and published: a bare tick and a grep that matched nothing because it was pointed at an
  # empty tree read exactly alike.
  n=$(git grep -lI '' -- . 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ no second person in versioned content — read: $n text file(s), repo/ only (workspace/ is deliberately French)"
  exit 0
fi

printf '%s\n' "$hits" >&2
echo "✗ second person is forbidden in versioned content (standard §1)." >&2
echo "  Rewrite impersonally — \"the user\", or a turn of phrase without an addressee." >&2
echo "  A genuinely legitimate case is added to ALLOW in this script, with its reason." >&2
exit 1
