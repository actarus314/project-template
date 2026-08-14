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

# The label of a generation is never a PREFIX of an earlier one — readings that must not be summed
# cannot share a name a grep would sweep up together.
record() {   # <rc> <reason>
  [ -n "$JOURNAL" ] || return 0
  printf '%s\thook\tpull request opened\t%s\t\t%s\t%s\n' \
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
# This event also fires on text the HARNESS injects, which the maintainer never typed — an agent
# reporting back quotes the gesture, and an authorisation granted by machine noise reads as an order.
INJECTED = ("<task-notification>", "<system-reminder>", "<local-command-stdout>", "<command-name>")
if any(t in txt for t in INJECTED): sys.exit(0)
# The verb and its target, up to 3 words apart, both on word boundaries. The measures that set the
# gap, and the cases each rule below answers for: docs/code/verify-pr-instruction.md.
VERB = r"ouvre|ouvres|ouvrir|cr[ée]{2}|cr[ée]er|cr[ée]es|lance|lancer|fais|faire|pr[ée]pare|pr[ée]parer"   # fr-pattern
ORDER = re.compile(r"\b(" + VERB + r")\b((?:\s+\S+){0,3}?)\s+(prs?|pull\s+requests?)\b", re.I)
# Orders carried by their expected RESULT, which name no opening verb at all.
RESULT = re.compile(r"open-pr\.sh|une pr par|en une pr|promeus|promeut", re.I)   # fr-pattern
# Three disqualifiers, read within the CLAUSE only. Widening the gap without them inverts the verdict:
# a ban on opening would arm the token, which is worse than the false negative being fixed.
NEG = re.compile(r"\b(ne|sans|pas|plus|jamais|ni|aucune?|arr[êe]te[rz]?|arr[êe]tes|stop|[ée]vite[rz]?|inutile)\b|\bn[\x27\u2019]", re.I)   # fr-pattern
GENERIC = re.compile(r"\b(des|de|d[\x27\u2019])$", re.I)   # "des PR" names the class; an order names the object   # fr-pattern
THIRD = re.compile(r"\b(renovate|dependabot|le bot|un bot|github)\b", re.I)   # a third party OPENS, it does not order   # fr-pattern
CLAUSE = re.compile(r"[.,;:!?\n—]|(?<=\s)-(?=\s)")
def ordered(txt):
    for m in ORDER.finditer(txt):
        head = txt[:m.start(1)]
        cut = max([c.end() for c in CLAUSE.finditer(head)] or [0])
        window, gap = head[cut:][-60:], m.group(2)
        if NEG.search(window) or NEG.search(gap): continue
        if GENERIC.search(gap.strip()) or THIRD.search(window): continue
        return True
    return bool(RESULT.search(txt))
sys.exit(7 if ordered(txt) else 0)
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
# In COMMAND POSITION, never anywhere in the string: substring presence is not execution.
# The two openings that proved it, one counted wrongly and one missed: verify-pr-instruction.md.
opens=$(printf '%s' "$cmd" | python3 -c '
import re, shlex, sys
OPEN = re.compile(r"(?:\S*/)?open-pr\.sh\s|gh\s+pr\s+create\b")
# Wrappers are peeled ONE token at a time, testing before each peel — a single regex either ate the
# target (./open-pr.sh looks like a path) or stopped short of it (direnv exec <dir> is three tokens).
PEEL = re.compile(r"^(?:cd|direnv|exec|env|sudo|time|command|nohup)$|^[-./~]\S*$|^\S+=\S*$")
OPS = {";", "&&", "||", "|", "&", "\n"}
# A heredoc is CONTENT, never commands this shell runs. Left in, any text that merely quotes the
# gesture — the documentation of this very check — reads as an opening. Measured: editing that note
# was recorded as a pull request being opened, and it consumed the token the real one then needed.
HEREDOC = re.compile(r"<<-?\s*[\"\x27]?(\w+)[\"\x27]?\n.*?\n\s*\1\s*$", re.S | re.M)
def segments(cmd):
    # Splitting on ; & | WITHOUT honouring quotes cuts strings open, so shlex separates the
    # operators itself; on unbalanced quotes it raises, and a plain split is all there is left.
    # A NEWLINE ends a command too and shlex swallows it as whitespace, hence the line split FIRST.
    cmd = HEREDOC.sub("\n", cmd)
    segs = []
    for line in cmd.split("\n"):
        lex = shlex.shlex(line, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        try: toks = list(lex)
        except ValueError:
            segs.extend(s.split() for s in re.split(r"[;&|]+", line)); continue
        cur = []
        for tok in toks:
            if tok in OPS: segs.append(cur); cur = []
            else: cur.append(tok)
        segs.append(cur)
    return segs
def opens(toks):
    toks = list(toks)
    while toks:
        if OPEN.match(" ".join(toks) + " "): return True
        if not PEEL.match(toks[0]): return False
        toks.pop(0)
    return False
print("yes" if any(opens(s) for s in segments(sys.stdin.read())) else "no")
' || echo no)
[ "$opens" = yes ] || exit 0

if [ -f "$TOKEN" ]; then
  # Consumed, never dated: an order and the opening it authorises sat up to 31 turns apart, so any
  # expiry short enough to restrict would refuse real orders. One order, one opening.
  rm -f "$TOKEN"
  record 0 "with an instruction"
else
  record 1 "WITHOUT an instruction"
fi
exit 0
