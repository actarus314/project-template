#!/usr/bin/env bash
# A `Stop` hook: two claims checked as the turn ends, against what the turn actually ran.
#
# The maintainer was doing this pass by hand, every time, because the thirteen other checks watch
# FILES and none watches what gets ASSERTED. Two failures kept coming back:
#   · a defect is named, and the turn ends without touching anything;
#   · a counted total is stated that appears in no tool output — typically relayed from a subagent.
#
# Both are COUNTED, never judged. That is deliberate: a model asked to review a turn gives a false
# green often enough to matter, and stacking several does not help — nine judges from seven families
# supply about two independent votes, and the best single judge matches the whole panel. So no model
# reviews anything here, and the thresholds come from measurement rather than from taste.
#
# 🔴 ADVISORY. It reports and lets the turn end. Blocking is a separate decision, to be taken only
# after the rate has been watched in real use — a guard that fires slightly too often is friction,
# and friction earns overrides until nobody reads it.
#
# The patterns were tuned against 4463 real turns of this project's own transcripts: the obvious
# wordings fired on ~15% of turns, which is unreadable. Each narrowing below is what brought them
# under 1%. Anything loosened here must be re-measured the same way, not eyeballed.
#
# Wiring (the settings file is local, never versioned — see docs/claude-code-setup.md):
#   "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "<abs>/verify-turn-claims.sh" } ] } ] }
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || exit 0   # no interpreter: stay out of the way, never block

# The payload is read FIRST, then the interpreter is fed from a file. `python3 - <<'PY'` would
# swallow stdin to read its own script, leaving the hook blind to the event it inspects.
payload=$(cat)
prog=$(mktemp)
trap 'rm -f "$prog"' EXIT
cat > "$prog" <<'PY'
import json, re, sys, pathlib

try:
    ev = json.load(sys.stdin)
except Exception:
    sys.exit(0)                       # unreadable payload: never complain about the guard itself

if ev.get("stop_hook_active"):        # already inside a relaunch: say nothing twice
    sys.exit(0)

msg = str(ev.get("last_assistant_message") or "")
if not msg.strip():
    sys.exit(0)

# What THIS turn ran, read back from the transcript: the tools invoked, and their outputs. Both
# come from the transcript and nowhere else — an earlier version proved which way this goes wrong.
# It used `git status` as its evidence of an edit, and during a working session the tree is almost
# never clean, so the guard fell silent nearly always: green, and blind.
#
# Reading stops at the previous USER message, which is where this turn began.
tools, outputs = [], []
tp = ev.get("transcript_path")
if tp:
    try:
        for ln in reversed(pathlib.Path(tp).read_text(encoding="utf-8", errors="replace").splitlines()):
            rec = json.loads(ln)
            m = rec.get("message") or {}
            content = m.get("content")
            if m.get("role") == "user" and isinstance(content, str):
                break                            # start of this turn
            for c in (content or []):
                if not isinstance(c, dict):
                    continue
                if c.get("type") == "tool_use":
                    tools.append(c.get("name", ""))
                elif c.get("type") == "tool_result":
                    r = c.get("content")
                    outputs.append(r if isinstance(r, str) else json.dumps(r))
    except Exception:
        tools, outputs = None, None
out = "\n".join(outputs) if outputs is not None else None

found = []

# Signal 1 — a defect asserted in the present tense, about a named file, left untouched.
# The wide wording ("absent", "mort", "aveugle" in ordinary technical prose) fired on 14% of turns;
# requiring the assertion form and a file reference brought it to 0.5%.
DEFECT = re.compile(r"(?:^|[.\n])[^.\n]{0,120}\b(?:est|sont|reste|restent|n'est pas|ne sont pas)\s+"
                    r"(?:\*\*)?(faux|périmée?s?|divergentes?|obsolètes?|incohérentes?|mortes?|absente?s?)\b", re.I)  # fr-pattern
HANDLED = re.compile(r"\b(corrigé|corrigée|fixé|réparé|✅|je corrige|j'ai corrigé)\b", re.I)  # fr-pattern
FILEREF = re.compile(r"[\w./-]+\.(?:sh|md|ya?ml|json|py|txt)\b")

# No transcript means no way to tell what the turn ran: say nothing rather than accuse.
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
edited = tools is None or bool(set(tools) & EDIT_TOOLS)

m = DEFECT.search(msg)
if m and not HANDLED.search(msg) and FILEREF.search(msg) and not edited:
    found.append(f'a defect is stated — "{" ".join(m.group(0).split())[:70]}" — '
                 f"and the turn ends with nothing edited")

# Signal 2 — a counted total that appears in no tool output. Restricted to numbers announced as a
# total, or produced while a subagent was consulted: any counted number fired on 4.7% of turns,
# this shape on 0.65%.
if out is not None:
    NUM = re.compile(r"(?<![#§v\d.])\b(\d{2,4})\b\s*(?:\*\*)?\s*"
                     r"(fichiers?|règles?|contrôles?|occurrences?|lignes?|scripts?|copies?|"
                     r"sessions?|paires?|mémoires?|commits?|erreurs?|défauts?)", re.I)
    TOTAL = re.compile(r"\b(total|au total|en tout|somme|cumul|soit)\b", re.I)
    used_agent = '"Agent"' in out or '"Task"' in out
    unbacked = [x for x in NUM.finditer(msg) if x.group(1) not in out]
    if unbacked and (TOTAL.search(msg) or used_agent):
        first = " ".join(unbacked[0].group(0).split())
        found.append(f'"{first}" is stated as a total but appears in no output of this turn')

if not found:
    sys.exit(0)

print(json.dumps({"systemMessage": "⚠ end-of-turn check (advisory): " + " · ".join(found)}))
sys.exit(0)                           # advisory: reports, never blocks
PY
printf "%s" "$payload" | python3 "$prog"
