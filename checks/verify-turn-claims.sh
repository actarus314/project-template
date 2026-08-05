#!/usr/bin/env bash
# hook: Stop — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# A `Stop` hook: two claims checked as the turn ends, against what the turn actually ran.
#
# The maintainer was doing this pass by hand, every time, because the thirteen other checks watch
# FILES and none watches what gets ASSERTED. Two failures kept coming back:
#   · a defect is named, and the turn ends without touching anything;
#   · a counted total is stated that appears in no tool output — typically relayed from a subagent;
#   · a table of MEASUREMENTS is rendered and nothing is written down, so the measurement dies with
#     the conversation. That third one was pointed out by the maintainer after it happened: timings
#     for every check were measured, shown, and never landed in any document.
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
# Wiring (the settings file is local, never versioned — see https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md):
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
partial = False          # at least one line of this turn could not be read
tp = ev.get("transcript_path")
if tp:
    try:
        for ln in reversed(pathlib.Path(tp).read_text(encoding="utf-8", errors="replace").splitlines()):
            # 🔴 PER LINE. One malformed line used to throw out of the whole loop and set both lists
            # to None, which disarms all three signals at once, in silence — a single unparseable
            # line anywhere in the turn. Measured: the signal fired on a healthy transcript and
            # vanished entirely when one junk line was appended.
            try:
                rec = json.loads(ln)
            except Exception:
                partial = True
                continue
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
# A PARTIAL read is a different case, and it splits the signals in two. What was seen can be
# asserted; what was NOT seen cannot. Signal 1 accuses on an ABSENCE (nothing edited), so an
# unread line could hold the very edit that clears it — it stands down. Signals 2 and 3 accuse on
# what is PRESENT in what was read, and a missing line can only make them quieter, never wrong.
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
edited = tools is None or partial or bool(set(tools) & EDIT_TOOLS)

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

# Signal 3 — a table of measurements rendered while nothing was written. Measuring is cheap and
# forgetting to record it is invisible: the numbers simply vanish with the turn. Vocabulary of
# measurement alone fired on 6% of turns and a table alone on 3.75%; requiring BOTH, with at least
# three numeric rows, brings it to 0.77%. A turn that wrote nothing at all is left alone — that is
# a conversation, not a lost measurement.
if tools:
    MEASURE = re.compile(r"\b(mesur|compt|médiane|mediane|centile|percentile|moyenne|taux|sur \d{2,})", re.I)  # fr-pattern
    if MEASURE.search(msg) and not edited:
        rows, run = [], []
        for line in msg.splitlines():
            s = line.strip()
            if s.startswith("|") and s.endswith("|"):
                run.append(s)
            else:
                if len(run) >= 2:
                    rows.append(run)
                run = []
        if len(run) >= 2:
            rows.append(run)
        for tbl in rows:
            body = tbl[2:] if re.match(r"^\|[\s:|-]+\|$", tbl[1]) else tbl[1:]
            if len(body) >= 3 and sum(1 for r in body if re.search(r"\d", r)) >= 3:
                found.append("a table of measurements was rendered and nothing was written — "
                             "the numbers die with this turn")
                break

if not found:
    sys.exit(0)

print(json.dumps({"systemMessage": "⚠ end-of-turn check (advisory): " + " · ".join(found)}))
sys.exit(0)                           # advisory: reports, never blocks
PY
printf "%s" "$payload" | python3 "$prog"
