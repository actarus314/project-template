#!/usr/bin/env bash
# hook: Stop, PreCompact — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# The development admin falling behind the work: commits piling up with nothing written down.
#
# TWO events, because there are two ways the record gets lost. `Stop` catches the drift, turn after
# turn. `PreCompact` catches the cliff: compaction drops the conversation, and everything decided in
# it that was never written down goes with it. The pass is worth asking for again there even when
# the turn-by-turn guard has already asked and been answered — which is why the "asked once" latch
# below does not apply to it.
#
# ⚠ On PreCompact it blocks ONLY when compaction was asked for by hand. An `auto` compaction means
#   the context window is full and Claude Code has to reclaim it; refusing that leaves the session
#   with nowhere to go. A guard that can wedge the tool it protects is worse than the drift it
#   watches, so `auto` gets the message and lets compaction through.
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
# ⚠ THE THRESHOLD IS MEASURED, not chosen — and it was measured TWICE, because the first reading
# used the wrong denominator. Counting how often a guard would actually SPEAK (once per crossing,
# not once per turn: between two commits the count does not move) across 21 days, 157 commits and
# 166 writes to the tracking doc:
#     S=4 → 11 times   S=5 → 4   S=6 → 3   S=7 → 3   S=8 → 3   S=10 → 2   S=12 → never
# On that average, S=4 spoke every 2,1 days against a pass asked for by hand every 2,3 — apparently
# ideal. It was not: a 21-day average flattens the sessions where the work is dense, and on the one
# day this guard shipped, S=4 would have spoken FIVE times. Unusable, and the maintainer said so
# before any measurement did.
#
# S=6 is the LOWEST threshold at minimum noise: the count bottoms out at 3 from S=6 onward, so 8 or
# 10 buy no quiet and only arrive later. The 90th percentile of observed backlogs is 4, which puts 6
# past ordinary drift and inside the real episodes. Moving it has to be re-measured the same way —
# on a dense day as well as on the average, since that is the difference the first reading missed.
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

THRESHOLD=${HOUSEKEEPING_THRESHOLD:-6}
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

# The payload is read for two fields only: which event this is, and — on PreCompact — whether the
# compaction was asked for or forced by a full context.
payload=$(cat)
EVENT=$(printf '%s' "$payload" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
TRIGGER=$(printf '%s' "$payload" | sed -n 's/.*"trigger"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$EVENT" ] || EVENT=Stop
case "$EVENT" in PreCompact) JOURNAL_NAME="housekeeping (before compaction)";; esac

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
# The latch holds for the turn-by-turn event only. Before compaction the record is about to be lost,
# so the question is worth putting again even if it was already put and set aside an hour ago.
if [ -f "$flag" ] && [ "$EVENT" != PreCompact ]; then
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

record 1 "behind=$behind event=$EVENT${TRIGGER:+ trigger=$TRIGGER}"
python3 - "$behind" "$extra" "$EVENT" "$TRIGGER" <<'PY'
import json, sys
behind, extra, event, trigger = sys.argv[1], sys.argv[2].strip(), sys.argv[3], sys.argv[4]
detail = f"{behind} commits have landed since the tracking doc was last written to"
if extra:
    detail += " — also: " + extra.rstrip(";")

out = {"systemMessage": f"⚠ housekeeping: {detail}"}
if event == "PreCompact":
    ask = (f"About to compact, and the development admin is behind: {detail}. Compaction drops the "
           f"conversation — anything decided in it and never written down goes with it. Run the "
           f"`housekeeping` skill first.")
    # Forced compaction means the context window is full; refusing it leaves the session stuck.
    if trigger == "auto":
        out["systemMessage"] = "⚠ housekeeping, before an automatic compaction: " + detail
    else:
        out.update({"decision": "block", "reason": ask})
else:
    out.update({"decision": "block",
                "reason": (f"Development admin is behind: {detail}. Run the `housekeeping` skill "
                           f"before ending the turn — it carries the checklist and decides what "
                           f"actually needs writing. If the pass genuinely does not apply here, say "
                           f"so in one line and finish; this will not ask again until the tracking "
                           f"doc is written to.")})
print(json.dumps(out))
PY
exit 0
