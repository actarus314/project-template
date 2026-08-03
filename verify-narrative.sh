#!/usr/bin/env bash
# Dated narrative in a code comment — forbidden by METHODE.md.
#
# The code says what it DOES. A comment says only what the code cannot say: a constraint that
# would otherwise recur. The story of how a defect was found — the date, the incident, the
# evidence — belongs to the archive, where it is dated, sourced and immutable.
#
# 🔴 THE RULE HELD BY DISCIPLINE ALONE, AND DISCIPLINE DOES NOT HOLD. The inventory recorded it
# as "already respected, nothing to build" — on a snapshot taken right after a manual review pass.
# That measured a rule freshly tidied, not a rule kept. Three violations appeared within hours,
# in the very scripts written to enforce other rules. The same story as verify-tone.sh.
#
# THE DISCRIMINATOR, and it comes from the one conforming case rather than from theory:
#
#   # (Full-Renovate switch, 2026-07 — see workspace/archives/2026-07-autodetection/SYNTHESE.md.)
#
# A date is allowed IFF the same line points into `archives/`. One line, one pointer, the story
# lives where stories live. Anything else with a date in a comment is the narrative itself.
#
# Scope: shell scripts, workflows and hooks — what is COMMENTED. Not markdown: a CHANGELOG, a
# runbook and an archive carry dates by design.
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# `git grep` on purpose, like verify-tone.sh: the rule is about what is COMMITTED. An untracked
# scratch file breaking it is nobody's business.
hits=$(git grep -nE '^[[:space:]]*#.*20[0-9]{2}-[0-9]{2}' -- '*.sh' '*.yml' '*.yaml' '.githooks/*' 2>/dev/null \
       | grep -v 'archives/' || true)

if [ -z "$hits" ]; then
  echo "✓ no dated narrative in code comments"
  exit 0
fi

echo "$hits" >&2
cat >&2 <<'EOF'

✗ dated narrative in a code comment — it belongs in the archive.
  Keep in the comment ONLY what the code cannot say. Move the account to
  workspace/archives/<stage>/, and leave a one-line pointer:
      # (What happened, in three words — see workspace/archives/<stage>/SYNTHESE.md.)
  A date is allowed only on a line that points into archives/.
EOF
exit 1
