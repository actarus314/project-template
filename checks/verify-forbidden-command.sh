#!/usr/bin/env bash
# hook: PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A PreToolUse hook on Bash: the commands this repo forbids, refused BEFORE they run.
#
# Each rule below is refused only because its verdict is MECHANICAL — a literal string, present or
# absent. That is the same test `verify-delegation.sh` states: no model judges anything here, so
# blocking is safe. A rule whose verdict depends on context is a WARNING instead, never a block: a
# guard wrong even one time in three teaches its own bypass, and the bypass then disarms the rules
# that were right.
#
# What NOT to add here: anything that has never actually happened. Measured over 4489 commands
# really executed across this project's 47 sessions, `gh pr merge --admin` occurred zero times.
# A rule that never bites costs maintenance and protects nothing, while every extra rule is another
# chance to be wrong — of roughly six guards written in a single day, three were green and blind on
# first writing.
#
# ⚠ Heredocs are stripped before matching, and that is not a detail: the very measurements that
#   sized these rules were shell commands CONTAINING these strings inside a heredoc. A naive match
#   would have blocked the work that justified it.
#
# Wiring (the settings file is local, never versioned — see https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md):
#   "hooks": { "PreToolUse": [ { "matcher": "Bash",
#     "hooks": [ { "type": "command", "command": "<abs>/verify-forbidden-command.sh" } ] } ] }
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
JOURNAL_NAME="forbidden-command (before run)"
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

if ev.get("tool_name") != "Bash":    # narrow trigger — anything else is none of this hook's business
    record("skip", "not a Bash call")
    sys.exit(0)

cmd = str((ev.get("tool_input") or {}).get("command") or "")

# Strip heredoc bodies: text fed to another program is not a command being run. Without this, a
# script that merely MENTIONS a forbidden string — a grep, a measurement, a document being written
# — is refused, which is how a guard earns its own bypass.
cmd = re.sub(r"<<-?\s*'?\"?(\w+)'?\"?.*?^\1", " ", cmd, flags=re.S | re.M)

# Each rule carries a TAG: it is what reaches the journal, and a journal column holds a name, never
# a paragraph. The full reason goes to whoever is stopped; the tag goes to whoever reads the rate.
FORCED = r"templates/repo/(\.envrc|CLAUDE\.md|requirements-ci\.txt)"
BLOCK = [
    ("git-rm-cached-forced",
     rf"git\s+rm\s+(-[\w-]+\s+)*--cached\b.*{FORCED}",
     "`git rm --cached` on a force-added template file. The neighbouring template .gitignore would "
     "then swallow it, and every generated project would ship without it — silently. AGENTS.md, "
     "\"Do not break\"."),
    ("pr-merge-admin",
     r"gh\s+pr\s+merge\b[^|;&]*--admin\b",
     "`--admin` bypasses the CI, which is the only gate that verifies the SHA256 of pinned assets. "
     "A dispatch that failed is re-pulled with close+reopen, never merged past."),
    ("pr-checks",
     r"gh\s+pr\s+checks\b",
     "`gh pr checks` needs the `Checks` permission, which cannot be granted on a fine-grained PAT: "
     "it returns 403 every time. Read the run list instead — "
     "`gh run list --commit \"$sha\" --json workflowName,status,conclusion` — and treat a MISSING "
     "workflow as not green. AGENTS.md."),
]
# 🔴 ASKED, not warned — and the difference is the whole point. This rule spent its life as a
# message printed before the command ran, and the assistant read straight past it: it fired when
# pull request #109 was opened and did not change a thing, not even a mention. A notice nobody acts
# on is worse than no notice, since it looks like a guard while guaranteeing nothing.
#
# The rule itself states that only the MAINTAINER can tell whether two pull requests carry the same
# undertaking — and it was putting that question to the assistant. `permissionDecision: "ask"` puts
# it where it belongs: the command stops, the human approves or refuses, and one keystroke settles
# what a paragraph of prose could not. Not `deny`, because the measurement below rules that out;
# not a message, because a message was already there and did nothing.
#
# 🔴 MEASURED, and the mechanical version of this rule was ruled OUT. Two candidates, on the 20 most
# recent pull requests:
#   · "a second one opened while the first is still OPEN" — the case with no defence, since the work
#     could have gone onto the existing branch. It happened ZERO times in 16 human pull requests: the
#     workflow is strictly open-merge-open. A guard for it would never bite, and the rule above says
#     what never happened gets no rule.
#   · "consecutive pull requests touching the same files" — real, but it does not separate a fault
#     from a legitimate stage: #94, #95 and #96 score highest and are the assumed steps of ONE
#     undertaking. It would refuse correct work. The ratio also misleads on small diffs (one shared
#     file out of two reads as 0,50) and bot batches open six in minutes.
# What survives decides nothing: state the OVERLAP, so the question below is answered on a fact.
ASK = [
    ("second-pr-same-undertaking",
     r"open-pr\.sh\b",
     "Before opening: does the PREVIOUS pull request carry the SAME undertaking? If it does, commit "
     "onto its branch and push — pushing is free, a pull request costs a full CI run. Each batch "
     "looks coherent in isolation, which is why the question is asked out loud. AGENTS.md."),
]

for tag, pattern, reason in BLOCK:
    if re.search(pattern, cmd, re.I):
        record(1, "denied: " + tag)
        print(json.dumps({
            "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny"},
            "systemMessage": "Forbidden by this repo: " + reason,
        }), file=sys.stderr)
        sys.exit(2)

def overlap():
    """Files this branch touches, against those the last merged pull request touched.

    Local and instantaneous — a PreToolUse hook cannot afford a network round trip. This repo
    squashes, so the tip of the default branch IS the previous pull request and its file list is one
    `git show` away. Silent on any failure: an unmeasurable overlap must never stop a command."""
    import subprocess
    def run(*a):
        p = subprocess.run(a, capture_output=True, text=True, timeout=5)
        return set(x for x in p.stdout.split("\n") if x.strip()) if p.returncode == 0 else set()
    base = "main" if run("git", "rev-parse", "--verify", "main") else "master"
    mine = run("git", "diff", "--name-only", f"{base}...HEAD")
    prev = run("git", "show", "--name-only", "--format=", base)
    if not mine or not prev:
        return ""
    shared = mine & prev
    if not shared:
        return (f" Measured: this branch shares NO file with the previous pull request "
                f"({len(mine)} touched) — a different subject, so a new one is likely right.")
    return (f" Measured: {len(shared)} of this branch's {len(mine)} file(s) were ALSO touched by the "
            f"previous pull request ({', '.join(sorted(shared)[:4])}{'…' if len(shared) > 4 else ''})"
            f" — that is the signal the question above is about.")

for tag, pattern, reason in ASK:
    if re.search(pattern, cmd, re.I):
        try:
            extra = overlap()
        except Exception:
            extra = ""               # a measurement never stops the command it comments on
        record(1, "asked: " + tag)
        print(json.dumps({
            "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask",
                                   "permissionDecisionReason": reason + extra},
        }))
        sys.exit(0)                  # the human decides; nothing here refuses anything

record(0)
sys.exit(0)
PY
printf "%s" "$payload" | python3 "$prog" "$JOURNAL" "$JOURNAL_NAME" "$PROJECT"
