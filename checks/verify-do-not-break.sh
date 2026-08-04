#!/usr/bin/env bash
# The invariants of AGENTS.md, "Do not break".
#
# What those entries have in common is the reason they are written down at all: breaking one of
# them produces NO error. The skill simply vanishes from the list, a session silently loses the
# documents it reasons from, a generated project silently ships without three of its files. Nothing
# reports any of it, in either direction — which is precisely the shape of rule that discipline
# never holds.
#
# Three targets, one script: multiplying tools is its own failure mode, and these three are read at
# the same moment, for the same question ("is anything quietly unplugged?").
#
# Two of the three live OUTSIDE the repository, so the CI has nothing to look at. When they are
# absent the script says so and moves on — but the third one, which is inside, always runs: a guard
# that skips everything and prints a tick is worse than no guard.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

fail=0
repo_root=$(pwd -P)

# 1 — the skill is reached through a SYMLINK into this repository. A copy would drift, and drifting
#     copies of these recipes are what the anchoring was meant to end.
skill_link="$HOME/.claude/skills/new-project"
if [ -e "$skill_link" ] || [ -L "$skill_link" ]; then
  if [ ! -L "$skill_link" ]; then
    echo "✗ $skill_link is NOT a symlink — a copy drifts, silently"
    fail=1
  else
    target=$(cd "$(dirname "$skill_link")" && cd "$(readlink "$skill_link")" 2>/dev/null && pwd -P || echo "")
    if [ "$target" != "$repo_root/skills/new-project" ]; then
      echo "✗ $skill_link points to '${target:-a dead path}', not $repo_root/skills/new-project"
      fail=1
    fi
  fi
else
  echo "  (skill not installed here — nothing to check)"
fi

# 2 — the three files the neighbouring template .gitignore would otherwise swallow. They are
#     tracked through `git add -f`, so `git rm --cached` removes them without a word.
forced="templates/repo/.envrc templates/repo/CLAUDE.md templates/repo/requirements-ci.txt"
for f in $forced; do
  if ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo "✗ $f is no longer tracked — the template .gitignore swallowed it (re-add with: git add -f $f)"
    fail=1
  fi
done

# 3 — the absolute paths the assistant's own instructions point at. They are read from disk at every
#     session start, so a moved file breaks every session without raising anything.
claude_md="$HOME/.claude/CLAUDE.md"
if [ -f "$claude_md" ]; then
  # The leading delimiter is part of the match and stripped afterwards: a pattern starting at any
  # `/` reads the relative `docs/x.md` as the absolute `/x.md`, and reports it dead. Only paths that
  # genuinely begin a token are absolute ones.
  while IFS= read -r p; do
    [ -e "$p" ] || { echo "✗ $claude_md points at a path that no longer exists: $p"; fail=1; }
  done < <(grep -oE '(^|[[:space:]`(])/[A-Za-z0-9._/-]+\.md' "$claude_md" | sed 's|^[^/]*||' | sort -u)
else
  echo "  (no assistant instructions here — nothing to check)"
fi

[ "$fail" = 0 ] && echo "✓ nothing quietly unplugged: skill link, forced-add files, absolute pointers"
exit "$fail"
