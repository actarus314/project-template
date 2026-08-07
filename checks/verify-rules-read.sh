#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# hook: SessionStart, PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# The rule documents must be READ before anything is written. A rule that is merely INJECTED reads as
# a fact, and nothing traces whether it was ever obeyed. Why the transcript is the signal, why a
# partial read does not count, and what re-arms it: docs/code/verify-rules-read.md.
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
SLUG=$(printf '%s' "$PROJECT" | tr '/' '-')
SINCE="$STATE_DIR/rules-read-$SLUG.since"
OK="$STATE_DIR/rules-read-$SLUG.ok"

record() {   # <rc> <reason>
  [ -n "$JOURNAL" ] || return 0
  printf '%s\thook\trules read\t%s\t\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$PROJECT" >> "$JOURNAL"
}

payload=$(cat)
EVENT=$(printf '%s' "$payload" | python3 -c '
import json, sys
try: print(json.load(sys.stdin).get("hook_event_name", ""))
except Exception: print("")
' || true)

# The documents are DETECTED, never listed: a project that does not hold them is not made to read
# them. A generated project holds none, so this check says so and stands down.
# TWO tiers, and the split is not about cost: a runbook is a document of GESTURES — read it at the
# gesture or not at all (why loading it up front is worse than not requiring it: the .md note).
required=()
for f in docs/METHODE.md docs/claude-code-project-standard.md; do [ -f "$REPO/$f" ] && required+=("$f"); done
GESTURE_DOC=docs/RUNBOOK.md; [ -f "$REPO/$GESTURE_DOC" ] || GESTURE_DOC=""
OKG="$STATE_DIR/rules-read-$SLUG.gesture.ok"

# A session that just started — or that was just COMPACTED — has none of it in context any more.
# Compaction is the case this exists for: the summary carries the documents' CONCLUSIONS, which is
# exactly what feels like having read them.
if [ "$EVENT" = SessionStart ]; then
  mkdir -p "$STATE_DIR"; rm -f "$OK" "$OKG"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$SINCE"
  [ ${#required[@]} -gt 0 ] && record 0 "armed for ${#required[@]} document(s)"
  exit 0
fi

[ -f "$SINCE" ] || exit 0               # no SessionStart seen: the hook is half-wired, and must not block

# Which tier is this? A command about to post a lifecycle gesture asks for the runbook, and for it
# alone — the other two are owed by every write, and their own marker attests to them.
cmd=$(printf '%s' "$payload" | python3 -c '
import json, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
print(str((ev.get("tool_input") or {}).get("command") or ""))
' || true)
case "$cmd" in
  *configure-repo.sh*|*init-project.sh*|*open-pr.sh*|*"git tag"*|*"gh pr merge"*|*"gh release"*)
    [ -n "$GESTURE_DOC" ] || exit 0
    required=("$GESTURE_DOC"); OK="$OKG" ;;
  *)
    [ -n "$cmd" ] && exit 0             # any other command: nothing is being posed, say nothing
    target=$(printf '%s' "$payload" | python3 -c '
import json, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
print(str((ev.get("tool_input") or {}).get("file_path") or ""))
' || true)
    case "$target" in "$REPO"/*) ;; *) exit 0;; esac   # only what lands in this repository
    ;;
esac

[ ${#required[@]} -gt 0 ] || exit 0     # nothing to read here — a generated project, or another repo
[ -f "$OK" ] && exit 0                  # already satisfied this session: never re-read the transcript

transcript=$(printf '%s' "$payload" | python3 -c '
import json, sys
try: print(json.load(sys.stdin).get("transcript_path", ""))
except Exception: print("")
' || true)
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0   # no transcript to read: say nothing, block nothing

missing=$(REQUIRED="${required[*]}" SINCE_TS="$(cat "$SINCE")" REPO="$REPO" \
  python3 - "$transcript" <<'PY' || true
import json, os, sys
req = {f for f in os.environ["REQUIRED"].split()}
since, repo = os.environ["SINCE_TS"], os.environ["REPO"]
seen = set()
for line in open(sys.argv[1], errors="ignore"):
    try: d = json.loads(line)
    except Exception: continue
    if d.get("timestamp", "") < since: continue
    c = (d.get("message") or {}).get("content")
    if not isinstance(c, list): continue
    for b in c:
        if not (isinstance(b, dict) and b.get("name") == "Read"): continue
        inp = b.get("input") or {}
        # A partial read is NOT a read: offset/limit means a passage was taken, not the document.
        if inp.get("offset") or inp.get("limit"): continue
        fp = str(inp.get("file_path") or "")
        rel = fp[len(repo) + 1:] if fp.startswith(repo + "/") else fp
        if rel in req: seen.add(rel)
print(" ".join(sorted(req - seen)))
PY
)

if [ -z "$missing" ]; then
  mkdir -p "$STATE_DIR"; : > "$OK"
  record 0 "all ${#required[@]} rule document(s) read in full"
  exit 0
fi

record 1 "not read: $missing"
python3 - "$missing" <<'PY' >&2
import json, sys
missing = sys.argv[1].split()
print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny"},
    "systemMessage": ("Read these IN FULL before acting — no offset, no limit: "
                      + ", ".join(missing)
                      + ". They are injected as context, never as an executed instruction, so nothing "
                        "records whether they were obeyed; and after a compaction the summary carries "
                        "their conclusions, which is exactly what feels like having read them."),
}))
PY
exit 2
