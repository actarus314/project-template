#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   (through `decision: block` on stdout — the exit stays 0, or the JSON is dropped)
# hook: Stop — fired by the assistant, never by check.sh: it reads its payload from STDIN.
#   (detail: docs/code/verify-turn-claims.md)

set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# The journal, if it is on — a hook lives in a LOCAL settings file, so nothing versioned proves it ran.
#   (detail: docs/code/verify-turn-claims.md)
JOURNAL_NAME="turn-claims (end of turn)"
REPO=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$(basename "$(dirname "$REPO")")/$(basename "$REPO")"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-controls"
JOURNAL="$STATE_DIR/controls-log.tsv"
[ -f "$STATE_DIR/journal-on" ] || JOURNAL=""     # off: nothing below records anything

# No interpreter: stay out of the way, never block — but say so, since a gate that is skipped and a
# gate that is gone read identically from the journal otherwise.
if ! command -v python3 >/dev/null 2>&1; then
  if [ -n "$JOURNAL" ]; then
    printf '%s\thook\t%s\tskip\t\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$JOURNAL_NAME" "no python3" "$PROJECT" >> "$JOURNAL"
  fi
  exit 0
fi

# The payload is read FIRST, then the interpreter is fed from a file. `python3 - <<'PY'` would
# swallow stdin to read its own script, leaving the hook blind to the event it inspects.
payload=$(cat)
prog=$(mktemp)
trap 'rm -f "$prog"' EXIT
cat > "$prog" <<'PY'
import json, re, sys, pathlib, datetime

JOURNAL, NAME = (sys.argv[1] if len(sys.argv) > 1 else ""), (sys.argv[2] if len(sys.argv) > 2 else "")
PROJECT = sys.argv[3] if len(sys.argv) > 3 else ""

def record(rc, why=""):
    """One line, in check.sh's own schema: ts, mode, control, rc, ms, reason.

    Written HERE rather than in the shell above because this is where the verdict exists — the same
    reason check.sh journals inside ok()/ko() and nowhere else. `skip` marks a turn that was never
    evaluated, so a rate reads off `ko / fired` without counting the turns nobody looked at."""
    if not JOURNAL:
        return
    try:
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with open(JOURNAL, "a", encoding="utf-8") as fh:
            fh.write(f"{ts}\thook\t{NAME}\t{rc}\t\t{why}\t{PROJECT}\n")
    except Exception:
        pass                          # telemetry never breaks the gate it measures

try:
    ev = json.load(sys.stdin)
except Exception:
    record("skip", "unreadable payload")
    sys.exit(0)                       # unreadable payload: never complain about the guard itself

if ev.get("stop_hook_active"):        # already inside a relaunch: say nothing twice
    record("skip", "already relaunched")
    sys.exit(0)

msg = str(ev.get("last_assistant_message") or "")
if not msg.strip():
    record("skip", "empty message")
    sys.exit(0)

# What THIS turn ran, read back from the transcript: the tools invoked, and their outputs.
#   (detail: docs/code/verify-turn-claims.md)
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

found, tags = [], []          # tags name the SIGNAL, so the journal says which one to retune

# Signal 1 — a defect asserted in the present tense, about a named file, left untouched.
# The wide wording ("absent", "mort", "aveugle" in ordinary technical prose) fired on 14 % of turns;
# requiring the assertion form and a file reference brought it to 0.5 %.
DEFECT = re.compile(r"(?:^|[.\n])[^.\n]{0,120}\b(?:est|sont|reste|restent|n'est pas|ne sont pas)\s+"
                    r"(?:\*\*)?(faux|périmée?s?|divergentes?|obsolètes?|incohérentes?|mortes?|absente?s?)\b", re.I)  # fr-pattern
# HANDLED exempts on the WORD, never on proof: it takes the turn at its word that the defect was
# dealt with. Deliberate — the alternative is a guard that calls a fixed defect a lie, which trains
# whoever reads it to stop reading. What it costs is the case where the word is written and nothing
# was done; that one is caught by the tracking doc, not here.
HANDLED = re.compile(r"\b(corrigé|corrigée|fixé|réparé|✅|je corrige|j'ai corrigé)\b", re.I)  # fr-pattern
FILEREF = re.compile(r"[\w./-]+\.(?:sh|md|ya?ml|json|py|txt)\b")

# No transcript means no way to tell what the turn ran: say nothing rather than accuse.
#   (detail: docs/code/verify-turn-claims.md)
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
edited = tools is None or partial or bool(set(tools) & EDIT_TOOLS)

m = DEFECT.search(msg)
if m and not HANDLED.search(msg) and FILEREF.search(msg) and not edited:
    found.append(f'a defect is stated — "{" ".join(m.group(0).split())[:70]}" — '
                 f"and the turn ends with nothing edited")
    tags.append("defect-unedited")

# Signal 2 — a counted total that appears in no tool output. Restricted to numbers announced as a
# total, or produced while a subagent was consulted: any counted number fired on 4.7 % of turns,
# this shape on 0.65 %.
if out is not None:
    # A French thousands separator is a SPACE, so `5 300` used to be read as the total `300` — the
    # tail of a number, announced as if it were the whole. Groups are matched as one number.
    NUM = re.compile(r"(?<![#§v\d.])\b(\d{1,4}(?:[  \u202f\u00a0]\d{3})*)\b\s*(?:\*\*)?\s*"
                     r"(fichiers?|règles?|contrôles?|occurrences?|lignes?|scripts?|copies?|"
                     r"sessions?|paires?|mémoires?|commits?|erreurs?|défauts?)", re.I)
    TOTAL = re.compile(r"\b(total|au total|en tout|somme|cumul|soit)\b", re.I)
    used_agent = '"Agent"' in out or '"Task"' in out
    # Tool output prints 5302, never "5 302": the separators come off before comparing, or every
    # French-formatted number would be unbacked by construction.
    plain = lambda n: n.replace(" ", "").replace("\u202f", "").replace("\u00a0", "")
    unbacked = [x for x in NUM.finditer(msg) if plain(x.group(1)) not in out]
    if unbacked and (TOTAL.search(msg) or used_agent):
        first = " ".join(unbacked[0].group(0).split())
        found.append(f'"{first}" is stated as a total but appears in no output of this turn')
        tags.append("unbacked-total")

# Signal 3 — measurements rendered while nothing was written: the numbers die with the turn.
#   (detail: docs/code/verify-turn-claims.md)
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
                tags.append("measurement-unwritten")
                break

if not found:
    record(0)
    sys.exit(0)

record(1, " ".join(tags))

# `decision: block` ends the turn's ending: the reason goes back to the model, which acts on it or
# states why it does not apply. `systemMessage` is a separate channel — it reaches the maintainer,
# who otherwise sees a turn resume with no visible cause. Exit stays 0: on a Stop hook, exit 2 also
# blocks but discards stdout, and both channels above live in it.
detail = " · ".join(found)
print(json.dumps({
    "decision": "block",
    "reason": ("End-of-turn check — " + detail + ". Settle it before ending the turn: make the "
               "change, or write the measurement down, or source the number from this turn's "
               "output. If the signal is wrong here, say so in one line and finish."),
    "systemMessage": "⚠ end-of-turn check: " + detail,
}))
sys.exit(0)
PY
printf "%s" "$payload" | python3 "$prog" "$JOURNAL" "$JOURNAL_NAME" "$PROJECT"
