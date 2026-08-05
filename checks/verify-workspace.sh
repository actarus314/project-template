#!/usr/bin/env bash
# The neighbouring workspace/ — the one place NO other control can see.
#
# 🔴 It has no remote, ON PURPOSE. That is what lets repo/ be public: workspace/ carries private
# repo names and incident accounts, and none of it must ever reach a forge. But the same property
# makes it invisible: no remote means no diff-vs-origin, no CI, no pull request — and check.sh runs
# inside repo/ without ever looking beside it. Missed four times for exactly that reason.
#
# What is mechanically verifiable, and only that:
#   · it exists and is a git repository        (a plain folder loses everything on a bad rm)
#   · it has NO remote                          ← the hard constraint, the one that protects repo/
#   · nothing named like a secret is tracked
#   · a single tracking document                (two = two competing sources, which METHODE forbids)
#
# ⚠ NOT verifiable, and never to be promised: whether what the tracking document SAYS is true.
#
# Silent no-op where there is no neighbouring workspace.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

ws=../workspace
# Saying so out loud rather than exiting mute: an absent neighbour and a clean neighbour produced
# the very same empty output, and this is the one check whose whole reason to exist is that nothing
# else looks over there.
[ -d "$ws" ] || { echo "  (no $ws beside this repo — nothing to check)"; exit 0; }

fail=0
say() { echo "✗ workspace/: $1" >&2; fail=1; }

if ! git -C "$ws" rev-parse --git-dir >/dev/null 2>&1; then
  say "not a git repository — a plain folder has no history and no safety net"
else
  remotes=$(git -C "$ws" remote 2>/dev/null || true)
  if [ -n "$remotes" ]; then
    say "HAS A REMOTE ($(echo "$remotes" | tr '\n' ' ')) — it carries private names; this must never be pushed"
  fi

  # Anything named like a secret, tracked. The names are what betray, not the contents:
  # gitleaks looks for secret-shaped strings, never for a file called secrets.md.
  tracked=$(git -C "$ws" ls-files 2>/dev/null | grep -iE '(^|/)(secrets?|\.env)(\.[a-z]+)?$' || true)
  [ -n "$tracked" ] && say "tracks a secret-named file: $(echo "$tracked" | tr '\n' ' ')"

  # ONE living tracking system. Archives are excluded: a closed stage keeps its own account.
  # Zero is not a fault — METHODE allows another system entirely, as long as there is only one.
  #
  # 🔴 A SYSTEM, not a file. Counting only `SUIVI|TRACKING|PROGRESS.md` was blind to the collision
  # METHODE actually forbids: a `.planning/` sitting beside a SUIVI.md is two systems for one
  # question, and it is the stale one that gets read first. Measured: such a workspace returned the
  # same "1 tracking doc" as one holding nothing else at all.
  n=$(git -C "$ws" ls-files 2>/dev/null | grep -icE '(^|/)(SUIVI|TRACKING|PROGRESS)\.md$' || true)
  systems=$n
  # ⚠ This list cannot be complete — no check can know every tracking tool. So it is NAMED in the
  # verdict below: whoever reads it sees what was looked for, and therefore what was not.
  OTHERS=".planning .gsd .taskmaster"
  found_others=""
  for d in $OTHERS; do
    if git -C "$ws" ls-files "$d" 2>/dev/null | grep -q .; then
      systems=$((systems + 1)); found_others="$found_others $d/"
    fi
  done
  [ "$systems" -gt 1 ] &&
    say "$systems tracking systems compete (${n} doc(s)${found_others:+, plus${found_others}}) — METHODE allows one, and the stale one gets read first"
fi

[ "$fail" = 0 ] && echo "✓ workspace: git, no remote, no secret tracked, ${systems:-0} tracking system(s) — looked for SUIVI/TRACKING/PROGRESS.md and $(echo "$OTHERS" | sed 's|\([^ ]*\)|\1/|g; s| |, |g') (any other tool is invisible here)"
exit "$fail"
