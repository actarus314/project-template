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
# Warned, not blocked: opening a second pull request is sometimes right — a change of SUBJECT
# justifies one. Only the maintainer can tell, so this states the question rather than deciding it.
WARN = [
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

for tag, pattern, reason in WARN:
    if re.search(pattern, cmd, re.I):
        record(1, "warned: " + tag)
        print(json.dumps({"systemMessage": "⚠ " + reason}))
        sys.exit(0)                  # advisory: states the question, lets the command through

record(0)
sys.exit(0)
PY
printf "%s" "$payload" | python3 "$prog" "$JOURNAL" "$JOURNAL_NAME" "$PROJECT"
