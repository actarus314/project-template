#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
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

  # 🔴 What the list above cannot see: every tracked top-level dot-directory, minus the editor and
  # forge ones. NAMED, never counted — calling an unknown directory a tracking system would fire on
  # the next editor that ships one, and a guard that fires where it should not earns overrides.
  # Filtered on `/` first: a tracked path holding a slash has a directory as its head, which beats
  # testing the disk for one git tracks and the worktree happens not to hold.
  INNOCENT=".github .gitlab .vscode .idea .devcontainer .husky .claude .config .cache .venv"
  unlisted=""
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case " $OTHERS $INNOCENT " in *" $d "*) continue;; esac
    unlisted="$unlisted $d/"
  done < <(git -C "$ws" ls-files 2>/dev/null | grep '/' | cut -d/ -f1 | grep -E '^\.[a-zA-Z]' | sort -u || true)

  # 🔴 The backlog holds OPEN work only — a closed item leaves for the state section or an archive.
  # That rule is written in the tracking doc itself, and it was written because closure markers had
  # piled up inside the backlog until it stopped answering "where do I put the effort".
  # It got broken again the same day, four markers deep, and no check noticed: growth was measured
  # (+24% against a 25% threshold, one point short) but growth is the SYMPTOM. The rule itself is
  # binary — a closed marker inside the open-work section — so it needs no threshold and no measure.
  # This is the shape a closing pass leaves behind when only its first half was done.
  #
  # ⚠ WHAT THIS CANNOT DO, and it must not be read as more. It matches a FORM, never a state: an
  #   item that is finished, left in place, and never marked at all is invisible to it. The marker
  #   is a habit of whoever writes the document, not a guarantee — and a check resting on a habit
  #   inherits that habit's reliability. The list below is widened for that reason and still cannot
  #   be complete.
  #   So this catches the closing pass whose second half was skipped, and nothing more. Whether the
  #   backlog still describes the open work is the same question as whether the tracking doc is
  #   TRUE, which this file states from its first lines is not verifiable and must never be promised.
  track=$(ls "$ws"/SUIVI.md "$ws"/docs/SUIVI.md 2>/dev/null | head -1 || true)
  if [ -z "$track" ]; then
    :   # no tracking doc of the shape this rule describes: nothing to say, and it is not a fault
  else
    # The section is found by heading, and the scan stops at the next heading of the same level —
    # a closure marker in the state section above is exactly where it BELONGS.
    #
    # 🔴 The marker counts only at the START OF A CELL. Anywhere else it is a MENTION, not a mark:
    # the very row describing this rule quotes "des lignes passent à ✅", and a loose match read that
    # sentence as a closed item. Same failure the forbidden-command hook pays for with heredocs, and
    # the wiring check with code lines — a literal appears in prose too.
    stale=$(awk '
      /^## / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }
      inside && /^\|/ && /\|[[:space:]]*(✅|✔|☑|~~|LIVRÉ|LIVRE|DONE|FAIT|TERMINÉ|TERMINE|CLOS)/ { print NR ": " substr($0, 1, 72) }   # fr-pattern: the doc it reads is French
    ' "$track" || true)
    if [ -n "$stale" ]; then
      say "closed items are sitting in the open-work section of $(basename "$track") — they belong in the state section or an archive:
$stale"
    fi
    read_backlog=" backlog hygiene"
  fi
fi

[ "$fail" = 0 ] && echo "✓ workspace: git, no remote, no secret tracked, ${systems:-0} tracking system(s)${read_backlog:+,${read_backlog}} — looked for SUIVI/TRACKING/PROGRESS.md and $(echo "${OTHERS:-}" | sed 's|\([^ ]*\)|\1/|g; s| |, |g')${unlisted:+; also tracked, unrecognised —$unlisted — name it above if it is a tracking tool}"
exit "$fail"
