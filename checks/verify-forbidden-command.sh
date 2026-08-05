#!/usr/bin/env bash
# hook: PreToolUse — fired by the assistant, never by check.sh: it reads its payload from STDIN.
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

command -v python3 >/dev/null 2>&1 || exit 0   # no interpreter: stay out of the way, never block

payload=$(cat)
prog=$(mktemp)
trap 'rm -f "$prog"' EXIT
cat > "$prog" <<'PY'
import json, re, sys

try:
    ev = json.load(sys.stdin)
except Exception:
    sys.exit(0)                      # unreadable payload: never block on the guard's own failure

if ev.get("tool_name") != "Bash":    # narrow trigger — anything else is none of this hook's business
    sys.exit(0)

cmd = str((ev.get("tool_input") or {}).get("command") or "")

# Strip heredoc bodies: text fed to another program is not a command being run. Without this, a
# script that merely MENTIONS a forbidden string — a grep, a measurement, a document being written
# — is refused, which is how a guard earns its own bypass.
cmd = re.sub(r"<<-?\s*'?\"?(\w+)'?\"?.*?^\1", " ", cmd, flags=re.S | re.M)

FORCED = r"templates/repo/(\.envrc|CLAUDE\.md|requirements-ci\.txt)"
BLOCK = [
    (rf"git\s+rm\s+(-[\w-]+\s+)*--cached\b.*{FORCED}",
     "`git rm --cached` on a force-added template file. The neighbouring template .gitignore would "
     "then swallow it, and every generated project would ship without it — silently. AGENTS.md, "
     "\"Do not break\"."),
    (r"gh\s+pr\s+merge\b[^|;&]*--admin\b",
     "`--admin` bypasses the CI, which is the only gate that verifies the SHA256 of pinned assets. "
     "A dispatch that failed is re-pulled with close+reopen, never merged past."),
    (r"gh\s+pr\s+checks\b",
     "`gh pr checks` needs the `Checks` permission, which cannot be granted on a fine-grained PAT: "
     "it returns 403 every time. Read the run list instead — "
     "`gh run list --commit \"$sha\" --json workflowName,status,conclusion` — and treat a MISSING "
     "workflow as not green. AGENTS.md."),
]
# Warned, not blocked: opening a second pull request is sometimes right — a change of SUBJECT
# justifies one. Only the maintainer can tell, so this states the question rather than deciding it.
WARN = [
    (r"open-pr\.sh\b",
     "Before opening: does the PREVIOUS pull request carry the SAME undertaking? If it does, commit "
     "onto its branch and push — pushing is free, a pull request costs a full CI run. Each batch "
     "looks coherent in isolation, which is why the question is asked out loud. AGENTS.md."),
]

for pattern, reason in BLOCK:
    if re.search(pattern, cmd, re.I):
        print(json.dumps({
            "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny"},
            "systemMessage": "Forbidden by this repo: " + reason,
        }), file=sys.stderr)
        sys.exit(2)

for pattern, reason in WARN:
    if re.search(pattern, cmd, re.I):
        print(json.dumps({"systemMessage": "⚠ " + reason}))
        sys.exit(0)                  # advisory: states the question, lets the command through

sys.exit(0)
PY
printf "%s" "$payload" | python3 "$prog"
