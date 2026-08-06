#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# The neighbouring workspace/ — the one place no other control can see (why: verify-workspace.md).
# Verifiable only: git repo, no remote, no secret-named file tracked, one tracking system.
# NOT verifiable, and never to be promised: whether the tracking document's CONTENT is true.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

ws=../workspace
# An absent neighbour and a clean one produce the same empty output — said out loud on purpose,
# since this is the one check whose whole reason to exist is looking over there (verify-workspace.md).
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

  # A tracked NAME betrays, not the content — gitleaks already scans content (verify-workspace.md).
  tracked=$(git -C "$ws" ls-files 2>/dev/null | grep -iE '(^|/)(secrets?|\.env)(\.[a-z]+)?$' || true)
  [ -n "$tracked" ] && say "tracks a secret-named file: $(echo "$tracked" | tr '\n' ' ')"

  # ONE tracking system (METHODE). Archives excluded: a closed stage keeps its own account.
  n=$(git -C "$ws" ls-files 2>/dev/null | grep -icE '(^|/)(SUIVI|TRACKING|PROGRESS)\.md$' || true)
  systems=$n
  # A SYSTEM, not a file — .planning/ beside a SUIVI.md is two systems too (verify-workspace.md).
  OTHERS=".planning .gsd .taskmaster"
  found_others=""
  for d in $OTHERS; do
    if git -C "$ws" ls-files "$d" 2>/dev/null | grep -q .; then
      systems=$((systems + 1)); found_others="$found_others $d/"
    fi
  done
  [ "$systems" -gt 1 ] &&
    say "$systems tracking systems compete (${n} doc(s)${found_others:+, plus${found_others}}) — METHODE allows one, and the stale one gets read first"

  # Named below, never counted as a fault by itself — this list of rival tools cannot be
  # complete, so the verdict publishes what it looked for (verify-workspace.md).
  INNOCENT=".github .gitlab .vscode .idea .devcontainer .husky .claude .config .cache .venv"
  unlisted=""
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case " $OTHERS $INNOCENT " in *" $d "*) continue;; esac
    unlisted="$unlisted $d/"
  done < <(git -C "$ws" ls-files 2>/dev/null | grep '/' | cut -d/ -f1 | grep -E '^\.[a-zA-Z]' | sort -u || true)

  # A closed item belongs in the state section or an archive, never in the open-work backlog —
  # catches only that FORM, a habit rather than a guarantee (rule and incident: verify-workspace.md).
  track=$(ls "$ws"/SUIVI.md "$ws"/docs/SUIVI.md 2>/dev/null | head -1 || true)
  if [ -z "$track" ]; then
    :   # no tracking doc of the shape this rule describes: nothing to say, and it is not a fault
  else
    # Marks only at the START of a cell — elsewhere it's prose quoting the rule, not a mark
    # (incident: verify-workspace.md).
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
