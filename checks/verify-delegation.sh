#!/usr/bin/env bash
# hook: PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A PreToolUse hook: the three delegation instructions, checked BEFORE the subagent is launched.
#
# The rule (https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md): a subagent does the work ITSELF, does not re-delegate,
# does not call the advisor, and runs on a cheaper model.
#
# 🔴 All three are OPT-INS. Left unwritten, the default does the opposite of all three, SILENTLY —
# which is why discipline alone never held: nothing reported the omission, in either direction.
#
# This is the only check in this repo that runs A PRIORI, and it is mechanical rather than a
# judgement: `model` is a field, and the other two are strings that are present or absent. No
# model reviews anything here, so blocking is safe.
#
# ⚠ Deliberately NARROW: everything other than a subagent launch exits immediately. A guard that
#   fires everywhere earns overrides until nobody reads it any more.
#
# Wiring (the settings file is local, never versioned — see https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md):
#   "hooks": { "PreToolUse": [ { "matcher": "Agent",
#     "hooks": [ { "type": "command", "command": "<abs>/verify-delegation.sh" } ] } ] }
#
# PreToolUse DOES fire on a subagent launch (tool_name = Agent), and tool_input carries `prompt`,
# `model` and `subagent_type` as separate fields — measured, not assumed.
# (How it was measured — see workspace/archives/2026-08-decoupage-par-sujet/SYNTHESE.md.)
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# The journal, if it is on. A hook is the most fragile gate there is: it lives in a LOCAL settings
# file outside every repository, and one that stops being declared simply never fires — no error,
# no output, no trace. Recording the firing is the only way an indicator can tell "this gate works"
# from "this gate is gone", and check.sh cannot do it: it never runs the hooks.
#
# 🔴 Two properties this needs, and neither is decorative: ANCHORED TO THE SCRIPT, never to the
# working directory — a hook fires wherever the session sits, and a relative path drops every
# firing from elsewhere in silence. And THE VERDICT, not merely the firing: a `0` written before
# the analysis answers "did the gate fire", never "did it bite".
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
