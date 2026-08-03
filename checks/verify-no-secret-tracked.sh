#!/usr/bin/env bash
# A file NAMED like a secret, tracked by git — in both repos.
#
# 🔴 gitleaks cannot see this, by design: it looks for secret-SHAPED strings inside files, never
# for a file CALLED .env or secrets.md. An empty .env, a secrets.md holding only headings, an
# .envrc before the token is pasted in — all pass gitleaks, get committed, and are then filled in.
# The leak happens at the NEXT commit, on a path nobody watches any more.
#
# The standard states these files are never tracked. Nothing verified it until now.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# .env.example and .gitleaksignore are DELIBERATE: one is the documented template, the other the
# exception list. Both are meant to be tracked, and both would match a naive pattern.
pattern='(^|/)(\.env|\.envrc|secrets?)(\.[a-z]+)?$'
fail=0

scan() {
  local dir="$1" label="$2" hit
  [ -d "$dir" ] || return 0
  # templates/ holds TEMPLATES, not secrets: templates/repo/.envrc is the model copied into every
  # generated project, tracked on purpose with `git add -f` (AGENTS.md forbids un-tracking it).
  hit=$(git -C "$dir" ls-files 2>/dev/null | grep -iE "$pattern" \
        | grep -vE '\.example$|gitleaksignore|^templates/' || true)
  if [ -n "$hit" ]; then
    echo "✗ $label tracks a secret-named file: $(echo "$hit" | tr '\n' ' ')" >&2
    fail=1
  fi
}

scan . 'repo/'
scan ../workspace 'workspace/'

[ "$fail" = 0 ] && echo "✓ no secret-named file tracked, in either repo"
exit "$fail"
