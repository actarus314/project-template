#!/usr/bin/env bash
# blocking: no   (what this does with a verdict; compared to the control table AND to its real exit code)
# hook: UserPromptSubmit, PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# Pull requests opened with no instruction from the maintainer. It MEASURES, it does not refuse:
# whether refusing is worth building is the question this instrument exists to answer.
# The threshold that decides that, and why the old 49% is not the baseline: docs/code/verify-pr-instruction.md.

set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$(basename "$(dirname "$REPO")")/$(basename "$REPO")"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-controls"
JOURNAL="$STATE_DIR/controls-log.tsv"
[ -f "$STATE_DIR/journal-on" ] || JOURNAL=""
TOKEN="$STATE_DIR/pr-instruction-$(printf '%s' "$PROJECT" | tr '/' '-').token"

record() {   # <rc> <reason>
  [ -n "$JOURNAL" ] || return 0
  printf '%s\thook\tpr opened\t%s\t\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$PROJECT" >> "$JOURNAL"
}

payload=$(cat)
EVENT=$(printf '%s' "$payload" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# The maintainer's words, watched for an instruction to open. The field carrying the prompt is not
# documented, so every text value is read — a named field that turns out wrong stays mute for hours.
if [ "$EVENT" = UserPromptSubmit ]; then
  printf '%s' "$payload" | python3 -c '
import json, re, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
META = {"hook_event_name", "session_id", "transcript_path", "cwd", "trigger", "permission_mode"}
txt = " ".join(v for k, v in ev.items() if k not in META and isinstance(v, str))
# Measured over 1281 real messages: 40 matches. The forms it misses are known and counted — an order
# carried by its expected RESULT ("une PR par repo", "promeus") names no opening verb at all.
PAT = r"(ouvre|ouvrir|cr[ée]{2}|cr[ée]er|lance|fais|pr[ée]pare)\s+(la|les|une|le)?\s*(pr|pull request)|open-pr\.sh|une pr par|en une pr|promeus|promeut"   # fr-pattern
sys.exit(7 if re.search(PAT, txt, re.I) else 0)
' && rc=0 || rc=$?
  [ "${rc:-0}" = 7 ] && { mkdir -p "$STATE_DIR"; date -u +%Y-%m-%dT%H:%M:%SZ > "$TOKEN"; }
  exit 0
fi

# PreToolUse: the gesture, not one script. gh pr create appeared 84 times in this repository's own
# history — a guard watching only open-pr.sh leaves the door beside it wide open.
cmd=$(printf '%s' "$payload" | python3 -c '
import json, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
print(str((ev.get("tool_input") or {}).get("command") or ""))
' || true)
case "$cmd" in *grep*|*shellcheck*) exit 0;; esac
printf '%s' "$cmd" | grep -qE 'open-pr\.sh[[:space:]]|gh pr create' || exit 0

if [ -f "$TOKEN" ]; then
  # Consumed, never dated: an order and the opening it authorises sat up to 31 turns apart, so any
  # expiry short enough to restrict would refuse real orders. One order, one opening.
  rm -f "$TOKEN"
  record 0 "with an instruction"
else
  record 1 "WITHOUT an instruction"
fi
exit 0
