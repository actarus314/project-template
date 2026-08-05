#!/usr/bin/env bash
# hook: Stop, PreCompact, UserPromptSubmit — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# The development admin falling behind the work: commits piling up with nothing written down.
# THREE events (Stop, PreCompact, UserPromptSubmit), threshold 6 commits since the last write.
# 🔴 IT DOES NOT DO THE PASS — it asks, and routes to the `housekeeping` skill.
# Why three, where 6 comes from, the routing patterns: docs/code/verify-housekeeping.md.

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

# ── UserPromptSubmit: the pass was ASKED FOR, in words. Route it, and stop there. ─────────────
# No backlog counting here — the trigger is the request itself, not the drift. Fires on every
# prompt, so it must be quiet and quick: everything that does not match leaves without a word.
if [ "$EVENT" = UserPromptSubmit ]; then
  JOURNAL_NAME="housekeeping (asked in words)"
  printf '%s' "$payload" | python3 -c '
import json, re, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
txt = str(ev.get("user_input") or "")
PAT = [
    r"passe[s]? de fin de chantier|fais (?:la|une) fin de chantier",   # fr-pattern
    r"je vais /?clear|que je puisse /?clear|(?:pour|avant)\s+(?:un\s+|le\s+|de\s+)?/?clear\b|/?clear pour repartir",   # fr-pattern
    r"(?:suivis?|repos locaux|docs et archives|tout)\s*(?:sont|est)?\s*(?:bien )?à jour\s*\?",   # fr-pattern
]
if not any(re.search(p, txt, re.I) for p in PAT):
    sys.exit(0)
# stdout on this event IS the context the model reads: state the instruction, not a hint.
print("[housekeeping] The maintainer just asked for the closing pass. Invoke the `housekeeping` "
      "skill now, before answering anything else — it carries the checklist and decides what "
      "actually needs writing. Measured: this request is followed by a write to the tracking doc "
      "9 times out of 9, against 55% for an ordinary moment.")
sys.exit(7)                      # 7: matched, so the shell below records it
' && rc=0 || rc=$?
  [ "${rc:-0}" = 7 ] && record 1 "routed to the housekeeping skill"
  exit 0
fi

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
