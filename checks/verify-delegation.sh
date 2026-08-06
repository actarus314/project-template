#!/usr/bin/env bash
# hook: PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A PreToolUse hook: the three delegation instructions — work itself, no re-delegation, no advisor,
# cheaper model — checked BEFORE the subagent launches. Rule, opt-in status, why blocking is safe:
# https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md.

# PreToolUse DOES fire on a subagent launch (tool_name = Agent), with `prompt`, `model` and
# `subagent_type` as separate fields in tool_input — measured, not assumed
# (workspace/archives/2026-08-decoupage-par-sujet/SYNTHESE.md).
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# The journal, if it is on — a hook lives in a LOCAL settings file, so nothing versioned proves it
# ran; why it must be anchored to the script and record the VERDICT: verify-turn-claims.md.
JOURNAL_NAME="delegation (before launch)"
REPO=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$(basename "$(dirname "$REPO")")/$(basename "$REPO")"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-controls"
JOURNAL="$STATE_DIR/controls-log.tsv"
[ -f "$STATE_DIR/journal-on" ] || JOURNAL=""

if ! command -v python3 >/dev/null 2>&1; then   # no interpreter: stay out of the way, never block
  if [ -n "$JOURNAL" ]; then
    printf '%s\thook\t%s\tskip\t\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$JOURNAL_NAME" "no python3" "$PROJECT" >> "$JOURNAL"
  fi
  exit 0
fi

# The payload is read FIRST, then the interpreter is fed from a file. `python3 - <<'PY'` would
# swallow stdin to read its own script, leaving the hook blind to the event it is meant to inspect
# — and silently passing, which is the worst failure a guard can have.
payload=$(cat)
prog=$(mktemp)
trap 'rm -f "$prog"' EXIT
cat > "$prog" <<'PY'
import json, re, sys, datetime

JOURNAL, NAME = (sys.argv[1] if len(sys.argv) > 1 else ""), (sys.argv[2] if len(sys.argv) > 2 else "")
PROJECT = sys.argv[3] if len(sys.argv) > 3 else ""

def record(rc, why=""):
    """check.sh's own schema: ts, mode, control, rc, ms, reason — written where the verdict exists."""
    if not JOURNAL:
        return
    try:
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with open(JOURNAL, "a", encoding="utf-8") as fh:
            fh.write(f"{ts}\thook\t{NAME}\t{rc}\t\t{why}\t{PROJECT}\n")
    except Exception:
        pass                         # telemetry never breaks the gate it measures

try:
    ev = json.load(sys.stdin)
except Exception:
    record("skip", "unreadable payload")
    sys.exit(0)                      # unreadable payload: never block on the guard's own failure

if ev.get("tool_name") != "Agent":   # narrow trigger — anything else is none of this hook's business
    record("skip", "not an Agent launch")
    sys.exit(0)

ti = ev.get("tool_input") or {}
prompt = str(ti.get("prompt") or "")
model = str(ti.get("model") or "")

CHEAP = ("haiku", "sonnet")
missing = []

if not any(c in model.lower() for c in CHEAP):
    missing.append(f"cheaper model — `model` is {model or 'unset'}, expected one of {', '.join(CHEAP)}")
if not re.search(r"deleg|délég|delèg|sous-agent|subagent", prompt, re.I):
    missing.append("no re-delegation — the prompt never mentions delegating, so the subagent will")
if not re.search(r"advisor", prompt, re.I):
    missing.append("no advisor — the prompt never mentions it, so the subagent will call it")

if not missing:
    record(0)
    sys.exit(0)

detail = " · ".join(missing)
record(1, "denied: " + ", ".join(m.split(" —")[0].split(" -")[0] for m in missing))
print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny"},
    "systemMessage": ("Delegation instructions missing: " + detail
                      + ". All three are opt-ins: unwritten, the default does the opposite of all "
                        "three, silently (https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md). Add them, then relaunch."),
}), file=sys.stderr)
sys.exit(2)
PY
printf "%s" "$payload" | python3 "$prog" "$JOURNAL" "$JOURNAL_NAME" "$PROJECT"
