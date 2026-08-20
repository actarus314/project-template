#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   (what this does with a verdict; compared to the control table AND to its real exit code)
# hook: SessionStart, PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# On a refusal the rule itself goes out, in plain text on STDERR with exit 2 — the only channel that
# reaches the model from here, and the one block a JSON field cannot override. Never print JSON: this
# hook's stdout is not read at all, and systemMessage addresses the user. Which tier owes a rule and
# which owes a read, and what re-arms it: docs/code/verify-rules-read.md.
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

# No interpreter: say so and stand down. Silent, this guard stops arming AND stops asking, while the
# markers of an earlier session survive to excuse the next one.
if ! command -v python3 >/dev/null 2>&1; then
  record skip "no python3"
  exit 0
fi

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
kind=$(printf '%s' "$payload" | python3 -c '
import json, re, shlex, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
ti = ev.get("tool_input") or {}
cmd = str(ti.get("command") or "")
if not cmd:
    print("write:" + str(ti.get("file_path") or ti.get("notebook_path") or "")); raise SystemExit
# In COMMAND POSITION, never anywhere in the string. Matching the substring refused a grep and a wc
# that merely NAMED a script, six times in one session — how a guard earns its own bypass. The
# technique and its measurements are verify-pr-instruction.sh and its note; keep the two in step.
GEST = re.compile(r"(?:\S*/)?(?:configure-repo|init-project|open-pr)\.sh\s|git\s+tag\b|gh\s+pr\s+merge\b|gh\s+release\b")
PEEL = re.compile(r"^(?:cd|direnv|exec|env|sudo|time|command|nohup)$|^[-./~]\S*$|^\S+=\S*$")
OPS = {";", "&&", "||", "|", "&", "\n"}
HEREDOC = re.compile(r"<<-?\s*[\"\x27]?(\w+)[\"\x27]?\n.*?\n\s*\1\s*$", re.S | re.M)
def segments(c):
    c = HEREDOC.sub("\n", c)
    out = []
    for line in c.split("\n"):
        lex = shlex.shlex(line, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        try: toks = list(lex)
        except ValueError:
            out.extend(s.split() for s in re.split(r"[;&|]+", line)); continue
        cur = []
        for tok in toks:
            if tok in OPS: out.append(cur); cur = []
            else: cur.append(tok)
        out.append(cur)
    return out
def poses(toks):
    toks = list(toks)
    while toks:
        if GEST.match(" ".join(toks) + " "): return True
        if not PEEL.match(toks[0]): return False
        toks.pop(0)
    return False
print("gesture" if any(poses(s) for s in segments(cmd)) else "command")
' || true)
case "$kind" in
  gesture)
    [ -n "$GESTURE_DOC" ] || exit 0
    required=("$GESTURE_DOC"); OK="$OKG" ;;
  # A command writes as surely as an edit tool does — a redirection, sed -i, a script called inline.
  # Naming the ones that write is a list that always misses one, and a missed write is a write nobody
  # sees; one notice too many costs a single extra message per session. So every command counts, and
  # only a tool call carrying a path is filtered on where that path lands.
  command) ;;
  write:*)
    case "${kind#write:}" in "$REPO"/*) ;; *) exit 0;; esac   # only what lands in this repository
    ;;
  *) exit 0 ;;                          # unreadable payload: never block on what could not be read
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

# The runbook is DATA — the order of the actions, the URLs, the exact values, who performs each. No
# short form stands in for it, so this tier keeps demanding the read and stays unsatisfied until it
# happens: its marker is written above, on the read, and nowhere else.
if [ "$OK" = "$OKG" ]; then
  record 1 "not read: $missing"
  printf '%s\n%s\n' \
    "Read $missing IN FULL before this gesture — no offset, no limit." \
    'It holds the order of the actions and who performs each, with the exact values. A gesture performed from memory is a wrong gesture.' >&2
  exit 2
fi

# The other tier is a RULE, and a rule fits in a sentence. Sending it beats ordering a read of the
# documents carrying it: the reading is the part that already feels done. The marker is written HERE,
# on the refusal, because once the rule has been sent there is no read left to observe.
mkdir -p "$STATE_DIR"; : > "$OK"
record 1 "rule sent in place of a read: $missing"
cat >&2 <<'RULE'
This first action is held back once, so that the rule it owes arrives here instead of a reading list.

A fact lives in ONE place. Before writing one, check whether it already lives elsewhere: if it does,
link it, and repair the original where it is wrong — never copy it. If removing a sentence breaks
nothing, it stays removed.

Versioned content is written in English, and never in the second person; a README carries English and
French together, deliberately. Whatever is not needed to clone, build or run the app lives beside the
repository — unless the app or the tooling reads it there, in which case it stays and is ignored.

The block lifts here: this rule is owed once per session, and it has just been sent. Everything that
follows goes through, whatever its target.
RULE
exit 2
