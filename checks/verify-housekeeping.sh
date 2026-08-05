#!/usr/bin/env bash
# hook: Stop — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# The development admin falling behind the work: commits piling up with nothing written down.
#
# This is the one thing no file-watching check can see. verify-growth.sh knows the tracking doc only
# ever grows; verify-stage-closure.sh knows a release left no archive. Neither knows that eleven
# commits have landed since anyone last wrote a line about what they were for.
#
# 🔴 IT DOES NOT DO THE PASS — it asks for it. What it measures is COUNTABLE (commits since the last
# write); what the pass itself requires is JUDGEMENT (does the tracking doc still reflect the work,
# is this stage closed, what should be pruned), and no counter settles that. So the verdict routes
# to the `housekeeping` skill, which carries the checklist and the writing. Code for what counts,
# a model only for what is judged.
#
# ⚠ THE THRESHOLD IS MEASURED, not chosen. Across 21 days, 157 commits and 166 writes to the
# tracking doc, counting how often a guard would actually SPEAK — once per crossing, not once per
# turn, since between two commits the count does not move and a per-turn guard would repeat itself
# for hours:
#     S=2 → 33 times   S=3 → 20   S=4 → 10   S=5 → 4   S=6 → 3   S=10 → 2
# Over the same period the maintainer asked for the pass by hand 9 times. **S=4 speaks once every
# 2,1 days against their 2,3** — it arrives just ahead of the request instead of replacing it with
# noise. Raising or lowering this has to be re-measured the same way.
#
# Other things worth saying — work left uncommitted, a branch never pushed — are REPORTED when the
# guard speaks, and never trigger it. Uncommitted work mid-session is the normal state of a working
# tree, and a guard firing on the normal state is one that gets bypassed within a day.
#
# Wiring (the settings file is local, never versioned — see https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md):
#   "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "<abs>/verify-housekeeping.sh" } ] } ] }
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

THRESHOLD=${HOUSEKEEPING_THRESHOLD:-4}
JOURNAL_NAME="housekeeping (end of turn)"
REPO=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$(basename "$(dirname "$REPO")")/$(basename "$REPO")"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-controls"
JOURNAL="$STATE_DIR/controls-log.tsv"
[ -f "$STATE_DIR/journal-on" ] || JOURNAL=""

record() {   # <rc|skip> <reason>
  [ -n "$JOURNAL" ] || return 0
  printf '%s\thook\t%s\t%s\t\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$JOURNAL_NAME" "$1" "$2" "$PROJECT" >> "$JOURNAL"
}

cat > /dev/null                      # the payload is read and dropped: nothing here needs it
WS="$REPO/../workspace"
TRACK="$WS/SUIVI.md"

# Perimeter, detected rather than assumed. A project with no neighbouring workspace, or one whose
# tracking doc lives elsewhere, is not in breach of anything — it says so instead of passing mute.
if [ ! -d "$WS/.git" ] || [ ! -f "$TRACK" ]; then
  record skip "no neighbouring tracking doc"
  exit 0
fi

last=$(git -C "$WS" log -1 --format=%aI -- SUIVI.md 2>/dev/null || true)
if [ -z "$last" ]; then
  record skip "tracking doc never committed"
  exit 0
fi

behind=$(git -C "$REPO" log --all --format=%H --since "$last" 2>/dev/null | grep -c . || true)
# One flag per project: a guard that repeats itself every turn between two commits is a guard
# nobody reads by the afternoon. It speaks on the CROSSING, then stays quiet until a write clears it.
flag="$STATE_DIR/housekeeping-$(printf '%s' "$PROJECT" | tr '/' '-').flag"
mkdir -p "$STATE_DIR"

if [ "$behind" -lt "$THRESHOLD" ]; then
  rm -f "$flag"
  record 0 ""
  exit 0
fi
if [ -f "$flag" ]; then
  record skip "already asked, waiting for a write"
  exit 0
fi
: > "$flag"

# What else is worth mentioning once the guard is speaking anyway. Reported, never a trigger.
extra=""
dirty_repo=$(git -C "$REPO" status --porcelain 2>/dev/null | grep -c . || true)
dirty_ws=$(git -C "$WS" status --porcelain 2>/dev/null | grep -c . || true)
[ "$dirty_repo" -gt 0 ] && extra="$extra $dirty_repo uncommitted change(s) in repo/;"
[ "$dirty_ws" -gt 0 ] && extra="$extra $dirty_ws uncommitted change(s) in workspace/;"
branch=$(git -C "$REPO" branch --show-current 2>/dev/null || true)
if [ -n "$branch" ] && ! git -C "$REPO" rev-parse --verify --quiet "origin/$branch" >/dev/null 2>&1; then
  extra="$extra branch '$branch' has never been pushed;"
fi

record 1 "behind=$behind"
python3 - "$behind" "$THRESHOLD" "$extra" <<'PY'
import json, sys
behind, threshold, extra = sys.argv[1], sys.argv[2], sys.argv[3].strip()
detail = f"{behind} commits have landed since the tracking doc was last written to"
if extra:
    detail += " — also: " + extra.rstrip(";")
print(json.dumps({
    "decision": "block",
    "reason": (f"Development admin is behind: {detail}. Run the `housekeeping` skill before ending "
               f"the turn — it carries the checklist and decides what actually needs writing. "
               f"If the pass genuinely does not apply here, say so in one line and finish; this "
               f"will not ask again until the tracking doc is written to."),
    "systemMessage": f"⚠ housekeeping: {detail}",
}))
PY
exit 0
