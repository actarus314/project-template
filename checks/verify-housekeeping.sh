#!/usr/bin/env bash
# hook: Stop, PreCompact, UserPromptSubmit — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# The development admin falling behind the work: commits piling up with nothing written down.
# THREE events (Stop, PreCompact, UserPromptSubmit), threshold 6 commits since the last write.
# 🔴 IT DOES NOT DO THE PASS — it asks, and routes to the `housekeeping` skill.
# Why three, where 6 comes from, the routing patterns: docs/code/verify-housekeeping.md.

set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

THRESHOLD=${HOUSEKEEPING_THRESHOLD:-6}
JOURNAL_NAME="housekeeping (end of turn)"
REPO=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$(basename "$(dirname "$REPO")")/$(basename "$REPO")"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-controls"
JOURNAL="$STATE_DIR/controls-log.tsv"
[ -f "$STATE_DIR/journal-on" ] || JOURNAL=""
SLUG=$(printf '%s' "$PROJECT" | tr '/' '-')
ARMED="$STATE_DIR/housekeeping-$SLUG.armed"        # a pass is under way: how many times it has been sent back
PASS="$STATE_DIR/housekeeping-$SLUG.pass"          # its artefact — EPHEMERAL, and never a second resume doc
CYCLES=${HOUSEKEEPING_CYCLES:-3}

record() {   # <rc|skip> <reason>
  [ -n "$JOURNAL" ] || return 0
  printf '%s\thook\t%s\t%s\t\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$JOURNAL_NAME" "$1" "$2" "$PROJECT" >> "$JOURNAL"
}

# Armed by all THREE routes, since the pass is reached by all three — arming on the asked-in-words
# one alone would leave the drift route, the most frequent, sequenced by nothing.
arm() { mkdir -p "$STATE_DIR"; [ -f "$ARMED" ] || printf '%s 0\n' "$(date +%s)" > "$ARMED"; }

# The payload is read for two fields only: which event this is, and — on PreCompact — whether the
# compaction was asked for or forced by a full context.
payload=$(cat)
EVENT=$(printf '%s' "$payload" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
TRIGGER=$(printf '%s' "$payload" | sed -n 's/.*"trigger"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$EVENT" ] || EVENT=Stop
case "$EVENT" in PreCompact) JOURNAL_NAME="housekeeping (before compaction)";; esac

# ── UserPromptSubmit: the pass was ASKED FOR, in words. Route it, and stop there. ─────────────
# No backlog counting here — the trigger is the request itself, not the drift. Fires on every
# prompt, so it must be quiet and quick: everything that does not match leaves without a word.
if [ "$EVENT" = UserPromptSubmit ]; then
  JOURNAL_NAME="housekeeping (asked in words)"
  # A pass ALREADY under way is not re-announced: routing again restarts a checklist that is
  # half-done, and the sequencer below is what finishes it (verify-housekeeping.md).
  if [ -f "$ARMED" ]; then
    echo "[housekeeping] The closing pass is already under way — continue it rather than starting" \
         "over. The end-of-turn check states what its artefact still has to cover."
    record 0 "already under way — not re-routed"
    exit 0
  fi
  field=$(printf '%s' "$payload" | python3 -c '
import json, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
# The field carrying the prompt is NOT documented for this event. Naming one and reading only it
# makes the guard mute if the name ever differs — and mute is indistinguishable from "did not fire".
META = {"hook_event_name", "session_id", "transcript_path", "cwd", "trigger", "permission_mode"}
cand = [k for k, v in ev.items() if k not in META and isinstance(v, str) and v.strip()]
print(",".join(cand) or "NONE")
' || true)
  printf '%s' "$payload" | python3 -c '
import json, re, sys
try: ev = json.load(sys.stdin)
except Exception: sys.exit(0)
META = {"hook_event_name", "session_id", "transcript_path", "cwd", "trigger", "permission_mode"}
txt = " ".join(v for k, v in ev.items() if k not in META and isinstance(v, str))
PAT = [
    r"passe[s]? de fin de chantier|fais (?:la|une) fin de chantier",   # fr-pattern
    r"je vais /?clear|que je puisse /?clear|(?:pour|avant)\s+(?:un\s+|le\s+|de\s+)?/?clear\b|/?clear pour repartir",   # fr-pattern
    r"(?:suivis?|repos locaux|docs et archives|tout)\s*(?:sont|est)?\s*(?:bien )?à jour\s*\?",   # fr-pattern
]
if not any(re.search(p, txt, re.I) for p in PAT):
    sys.exit(0)
# stdout on this event IS the context the model reads: state the instruction, not a hint.
print("[housekeeping] The maintainer just asked for the closing pass. Invoke the `housekeeping` "
      "skill now, before answering anything else — it carries the checklist and decides what "
      "actually needs writing. Measured: this request is followed by a write to the tracking doc "
      "9 times out of 9, against 55% for an ordinary moment.")
sys.exit(7)                      # 7: matched, so the shell below records it
' && rc=0 || rc=$?
  if [ "${rc:-0}" = 7 ]; then
    record 1 "routed to the housekeeping skill (fields: ${field:-?})"
    arm
  else
    # Silence on a non-match used to make "fired and did not match" identical to "never fired" —
    # which is what left a real gap unexplainable. It now records what it read.
    record 0 "no match (fields: ${field:-?})"
  fi
  exit 0
fi

WS="$REPO/../workspace"
TRACK="$WS/SUIVI.md"

# Perimeter, detected rather than assumed. A project with no neighbouring workspace, or one whose
# tracking doc lives elsewhere, is not in breach of anything — it says so instead of passing mute.
if [ ! -d "$WS/.git" ] || [ ! -f "$TRACK" ]; then
  record skip "no neighbouring tracking doc"
  exit 0
fi

last=$(git -C "$WS" log -1 --format=%aI -- SUIVI.md 2>/dev/null || true)
if [ -z "$last" ]; then
  record skip "tracking doc never committed"
  exit 0
fi

behind=$(git -C "$REPO" log --all --format=%H --since "$last" 2>/dev/null | grep -c . || true)
# One flag per project: a guard that repeats itself every turn between two commits is a guard
# nobody reads by the afternoon. It speaks on the CROSSING, then stays quiet until a write clears it.
flag="$STATE_DIR/housekeeping-$SLUG.flag"
mkdir -p "$STATE_DIR"

# ── The sequencer: a pass under way does not end the turn until its artefact COVERS the doc ──────
# A skill is text, so a step skips itself and nothing sees it. What is counted is coverage, never
# presence — every backlog item and every `##` section named, each with a verdict from a closed set.
# The 3-cycle ceiling, what is deliberately NOT implemented, and the artefact's shape:
# docs/code/verify-housekeeping.md.
if [ "$EVENT" = Stop ] && [ -f "$ARMED" ]; then
  JOURNAL_NAME="housekeeping (pass under way)"
  read -r armed_at used < "$ARMED"
  # Disarmed by a WRITE to the tracking doc, never by the turn ending: the pass is over when the
  # doc moved. Falling back on the threshold would disarm a pass asked for with no drift at all.
  if [ "$(git -C "$WS" log -1 --format=%at -- SUIVI.md 2>/dev/null || echo 0)" -gt "$armed_at" ]; then
    rm -f "$ARMED" "$PASS"
    record 0 "pass closed — the tracking doc was written"
    exit 0
  fi
  # Inline, like this file's other two: `check.sh`'s generator copies `verify-*.sh` and nothing
  # else, so a sibling .py would be missing in every generated project — a path dying on landing.
  gap=$(TRACK="$TRACK" PASS="$PASS" python3 -c '
import os, re
doc = open(os.environ["TRACK"], encoding="utf-8").read().splitlines()
items = [m.group(1) for l in doc if (m := re.match(r"\| \*\*(\d+)\*\* \|", l))]
sections = [l[3:].strip() for l in doc if l.startswith("## ")]
try: art = open(os.environ["PASS"], encoding="utf-8").read()
except OSError: art = ""
V = r"\s*:\s*(open|closed|unchanged)\b"
missing  = [f"item {n}"      for n in items    if not re.search(rf"item\s+{n}{V}", art, re.I)]
missing += [f"section {s!r}" for s in sections if not re.search(re.escape(s) + V, art, re.I)]
# The denominator is published even when nothing is missing: a coverage figure with no total is
# the shape of claim this whole check exists to refuse.
if missing:
    print(f"{len(missing)} of {len(items) + len(sections)} entries uncovered:")
    for m in missing: print(f"  - {m}")
') || gap="the artefact could not be read"
  if [ -z "$gap" ]; then
    record 0 "artefact covers the tracking doc"
    exit 0
  fi
  used=$((used + 1))
  printf '%s %s\n' "$armed_at" "$used" > "$ARMED"
  if [ "$used" -ge "$CYCLES" ]; then
    rm -f "$ARMED"
    record 1 "ceiling of $CYCLES reached — released, gap published"
    printf '{"systemMessage":"⚠ housekeeping: %s cycles reached, the turn is released. STILL UNCOVERED: %s"}\n' \
      "$CYCLES" "$(printf '%s' "$gap" | tr '\n' ' ' | sed 's/"/\\"/g')"
    exit 0
  fi
  record 1 "sent back — cycle $used/$CYCLES"
  python3 - "$used/$CYCLES" "$PASS" "$gap" <<'PY'
import json, sys
cycle, artefact, gap = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({"decision": "block",
  "systemMessage": f"⚠ housekeeping: artefact incomplete (cycle {cycle})",
  "reason": (f"The closing pass is under way and its artefact does not yet cover the tracking doc. "
             f"Write {artefact} — one line per entry, `<key>: <open|closed|unchanged>`, and the "
             f"next concrete gesture where the verdict is `open`. Naming an entry without a "
             f"verdict does not count it.\n\nSTILL MISSING:\n{gap}")}))
PY
  exit 0
fi

if [ "$behind" -lt "$THRESHOLD" ]; then
  rm -f "$flag"
  record 0 ""
  exit 0
fi
# The latch holds for the turn-by-turn event only. Before compaction the record is about to be lost,
# so the question is worth putting again even if it was already put and set aside an hour ago.
if [ -f "$flag" ] && [ "$EVENT" != PreCompact ]; then
  record skip "already asked, waiting for a write"
  exit 0
fi
: > "$flag"
arm                      # the drift route reaches the same pass, so it arms the same sequencer

# What else is worth mentioning once the guard is speaking anyway. Reported, never a trigger.
extra=""
dirty_repo=$(git -C "$REPO" status --porcelain 2>/dev/null | grep -c . || true)
dirty_ws=$(git -C "$WS" status --porcelain 2>/dev/null | grep -c . || true)
[ "$dirty_repo" -gt 0 ] && extra="$extra $dirty_repo uncommitted change(s) in repo/;"
[ "$dirty_ws" -gt 0 ] && extra="$extra $dirty_ws uncommitted change(s) in workspace/;"
branch=$(git -C "$REPO" branch --show-current 2>/dev/null || true)
if [ -n "$branch" ] && ! git -C "$REPO" rev-parse --verify --quiet "origin/$branch" >/dev/null 2>&1; then
  extra="$extra branch '$branch' has never been pushed;"
fi

record 1 "behind=$behind event=$EVENT${TRIGGER:+ trigger=$TRIGGER}"
python3 - "$behind" "$extra" "$EVENT" "$TRIGGER" <<'PY'
import json, sys
behind, extra, event, trigger = sys.argv[1], sys.argv[2].strip(), sys.argv[3], sys.argv[4]
detail = f"{behind} commits have landed since the tracking doc was last written to"
if extra:
    detail += " — also: " + extra.rstrip(";")

out = {"systemMessage": f"⚠ housekeeping: {detail}"}
if event == "PreCompact":
    ask = (f"About to compact, and the development admin is behind: {detail}. Compaction drops the "
           f"conversation — anything decided in it and never written down goes with it. Run the "
           f"`housekeeping` skill first.")
    # Forced compaction means the context window is full; refusing it leaves the session stuck.
    if trigger == "auto":
        out["systemMessage"] = "⚠ housekeeping, before an automatic compaction: " + detail
    else:
        out.update({"decision": "block", "reason": ask})
else:
    out.update({"decision": "block",
                "reason": (f"Development admin is behind: {detail}. Run the `housekeeping` skill "
                           f"before ending the turn — it carries the checklist and decides what "
                           f"actually needs writing. If the pass genuinely does not apply here, say "
                           f"so in one line and finish; this will not ask again until the tracking "
                           f"doc is written to.")})
print(json.dumps(out))
PY
exit 0
