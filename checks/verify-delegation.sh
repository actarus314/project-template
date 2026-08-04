#!/usr/bin/env bash
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

command -v python3 >/dev/null 2>&1 || exit 0   # no interpreter: stay out of the way, never block

# The payload is read FIRST, then the interpreter is fed from a file. `python3 - <<'PY'` would
# swallow stdin to read its own script, leaving the hook blind to the event it is meant to inspect
# — and silently passing, which is the worst failure a guard can have.
payload=$(cat)
prog=$(mktemp)
trap 'rm -f "$prog"' EXIT
cat > "$prog" <<'PY'
import json, re, sys

try:
    ev = json.load(sys.stdin)
except Exception:
    sys.exit(0)                      # unreadable payload: never block on the guard's own failure

if ev.get("tool_name") != "Agent":   # narrow trigger — anything else is none of this hook's business
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
    sys.exit(0)

detail = " · ".join(missing)
print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny"},
    "systemMessage": ("Delegation instructions missing: " + detail
                      + ". All three are opt-ins: unwritten, the default does the opposite of all "
                        "three, silently (https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md). Add them, then relaunch."),
}), file=sys.stderr)
sys.exit(2)
PY
printf "%s" "$payload" | python3 "$prog"
