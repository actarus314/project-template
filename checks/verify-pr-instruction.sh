#!/usr/bin/env bash
# blocking: no   (what this does with a verdict; compared to the control table AND to its real exit code)
# hook: UserPromptSubmit, PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# Pull requests opened with no instruction from the maintainer. It MEASURES, it does not refuse:
# whether refusing is worth building is the question this instrument exists to answer.
# The threshold that decides that, and why the old 49 % is not the baseline: docs/code/verify-pr-instruction.md.

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
TOKEN="$STATE_DIR/pr-instruction-$SLUG.token"
LAST="$STATE_DIR/pr-instruction-$SLUG.last"     # the opening last counted, so a retry is not a second one

# A generation's label is never a PREFIX of an earlier one, and a retry takes one of its own:
# readings that must not be summed cannot share a name a grep sweeps up together.
record() {   # <rc> <reason> [label]
  [ -n "$JOURNAL" ] || return 0
  printf '%s\thook\t%s\t%s\t\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${3:-pull request opened}" "$1" "$2" "$PROJECT" >> "$JOURNAL"
}

# No interpreter: say so and stay out of the way, like the three neighbouring hooks. Silent, this
# instrument stops measuring while the journal still looks healthy — and a rate would be read from it.
if ! command -v python3 >/dev/null 2>&1; then
  record skip "no python3"
  exit 0
fi

payload=$(cat)
EVENT=$(printf '%s' "$payload" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
# The session: the field two neighbouring checks already rely on in flight, session_id being unproven.
SESSION=$(printf '%s' "$payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

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
# `plus` stays out: comparative far more often, and the ne/n- forms carry every negation it joins.
NEG = re.compile(r"\b(ne|sans|pas|jamais|ni|aucune?|arr[êe]te[rz]?|arr[êe]tes|stop|[ée]vite[rz]?|inutile)\b|\bn[\x27\u2019]", re.I)   # fr-pattern
GENERIC = re.compile(r"\b(des|de|d[\x27\u2019])$", re.I)   # "des PR" names the class; an order names the object   # fr-pattern
THIRD = re.compile(r"\b(renovate|dependabot|le bot|un bot|github)\b", re.I)   # a third party OPENS, it does not order   # fr-pattern
CLAUSE = re.compile(r"[.,;:!?\n—]|(?<=\s)-(?=\s)")
def ordered(txt):
    for m in ORDER.finditer(txt):
        head = txt[:m.start(1)]
        cut = max([c.end() for c in CLAUSE.finditer(head)] or [0])
        window, gap = head[cut:][-60:], m.group(2)
        if NEG.search(window) or NEG.search(gap): continue
        # The generic marker sits in the gap, or just before the verb when nothing separates them.
        if GENERIC.search(gap.strip() or window.strip()) or THIRD.search(window): continue
        return True
    return bool(RESULT.search(txt))
sys.exit(7 if ordered(txt) else 0)
' && rc=0 || rc=$?
  # ANY prompt reopens the count, armed or not: a retry follows its refusal within the same turn,
  # so once the maintainer has spoken again, the next identical opening is a second one.
  rm -f "$LAST"
  [ "${rc:-0}" = 7 ] && { mkdir -p "$STATE_DIR"; printf '%s\n%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" > "$TOKEN"; }
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
# Peeled ONE token at a time, testing before each peel: one regex ate the target or stopped short.
PEEL = re.compile(r"^(?:cd|direnv|exec|env|sudo|time|command|nohup)$|^[-./~]\S*$|^\S+=\S*$")
OPS = {";", "&&", "||", "|", "&", "\n"}
# A heredoc is CONTENT, never commands this shell runs: text quoting the gesture read as an opening.
HEREDOC = re.compile(r"<<-?\s*[\"\x27]?(\w+)[\"\x27]?\n.*?\n\s*\1\s*$", re.S | re.M)
def segments(cmd):
    # shlex separates the operators, quotes honoured; on unbalanced quotes it raises and a plain
    # split is all there is left. A NEWLINE ends a command and shlex swallows it: line split FIRST.
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
# The WHOLE segment, wrappers included: the peel FINDS the gesture, it must not name it. Peeled,
# two repositories read alike and the second opening left the count as a retry.
def opens(toks):
    toks = list(toks)
    while toks:
        if OPEN.match(" ".join(toks) + " "): return True
        if not PEEL.match(toks[0]): return False
        toks.pop(0)
    return False
for seg in segments(sys.stdin.read()):
    if opens(seg):
        print(" ".join(seg)); break
' || true)
[ -n "$opens" ] || exit 0

# A refused opening consumes the order too. Two openings repeating the same peeled command with no
# order in between cannot be two pull requests: the first one did not get made.
if [ "$(cat "$LAST" 2>/dev/null || true)" = "$opens" ]; then
  record 0 "retry of the same opening" "pull request retried"
  exit 0
fi
mkdir -p "$STATE_DIR"; printf '%s' "$opens" > "$LAST"

if [ ! -f "$TOKEN" ]; then
  record 1 "WITHOUT an instruction"
# An order does not outlive its session; an absent field is published, never assumed.
elif [ -n "$SESSION" ] && [ -n "$(sed -n 2p "$TOKEN")" ] && [ "$(sed -n 2p "$TOKEN")" != "$SESSION" ]; then
  rm -f "$TOKEN"
  record 1 "WITHOUT an instruction — the order came from an earlier session"
else
  # Consumed, never dated: an order and the opening it authorises sat up to 31 turns apart, so any
  # expiry short enough to restrict would refuse real orders. One order, one opening.
  s=$(sed -n 2p "$TOKEN"); rm -f "$TOKEN"
  if [ -n "$s" ]; then record 0 "with an instruction"
  else record 0 "with an instruction — session unknown"; fi
fi
exit 0
