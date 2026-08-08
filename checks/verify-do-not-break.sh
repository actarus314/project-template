#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# The invariants of AGENTS.md, "Do not break" — plus the hooks, which fail the same silent way but
# live outside any file this repo tracks. Why one script covers all of them, and the two incidents
# that shaped the checks below: verify-do-not-break.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

fail=0
repo_root=$(pwd -P)
read_targets=""   # what this run actually looked at
skipped=""        # what it did not, and why it could not

# 1 — the skill symlink (the list this guards: verify-do-not-break.md). Every skill under skills/ is checked, detected
#     rather than named, and skipped where it is not installed on this machine.
if [ ! -d skills ]; then
  skipped="$skipped skill-link(this repository holds no skill)"
else
  seen_link=0
  for s in skills/*/; do
    [ -d "$s" ] || continue
    name=$(basename "$s")
    link="$HOME/.claude/skills/$name"
    if [ ! -e "$link" ] && [ ! -L "$link" ]; then
      skipped="$skipped skill-link:$name(not installed here)"
      continue
    fi
    seen_link=1
    if [ ! -L "$link" ]; then
      echo "✗ $link is NOT a symlink — a copy drifts, silently"
      fail=1
    else
      target=$(cd "$(dirname "$link")" && cd "$(readlink "$link")" 2>/dev/null && pwd -P || echo "")
      if [ "$target" != "$repo_root/skills/$name" ]; then
        echo "✗ $link points to '${target:-a dead path}', not $repo_root/skills/$name"
        fail=1
      fi
    fi
  done
  [ "$seen_link" = 1 ] && read_targets="$read_targets skill-link($(ls -d skills/*/ 2>/dev/null | wc -l | tr -d ' ') skill(s))"
fi

# 2 — the three files AGENTS.md pins (git add -f, the neighbouring template .gitignore). Checked
#     only where templates/ exists: elsewhere there is no generator to hold them.
forced="templates/repo/.envrc templates/repo/CLAUDE.md templates/repo/requirements-ci.txt"
if [ -d templates/repo ]; then
  for f in $forced; do
    if ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      echo "✗ $f is no longer tracked — the template .gitignore swallowed it (re-add with: git add -f $f)"
      fail=1
    fi
  done
  read_targets="$read_targets forced-add-files"
else
  skipped="$skipped forced-add-files(no templates/ here)"
fi

# 2b — CLAUDE.md, on a repository that is already public. It is the only thing that loads AGENTS.md,
#      and putting it back in .gitignore breaks that silently. Detected, never assumed: an adopted
#      repository may not have brought it in yet (standard §6).
if [ "$(git config --get remote.origin.url 2>/dev/null)" ] && git ls-files --error-unmatch CLAUDE.md >/dev/null 2>&1; then
  if ! grep -q "@AGENTS.md" CLAUDE.md; then
    echo "✗ CLAUDE.md no longer imports @AGENTS.md — nothing loads the rules any more"
    fail=1
  fi
  # The rule is CONTENT, not just presence: a machine path is the shape a personal line takes.
  if grep -nE "/Users/[a-z]|/home/[a-z]" CLAUDE.md; then
    echo "✗ CLAUDE.md carries a machine path, and this file is published (standard §6)"
    fail=1
  fi
  read_targets="$read_targets versioned-claude-md"
elif git ls-files --error-unmatch CLAUDE.md >/dev/null 2>&1; then
  read_targets="$read_targets versioned-claude-md"
else
  skipped="$skipped versioned-claude-md(not tracked here — private repo keeps it out)"
fi

# 3 — the absolute paths AGENTS.md pins, read from disk at every session start.
claude_md="$HOME/.claude/CLAUDE.md"
if [ -f "$claude_md" ]; then
  # The leading delimiter is part of the match and stripped afterwards: unanchored, the pattern
  # would read the relative `docs/x.md` as the absolute `/x.md` and report it dead.
  while IFS= read -r p; do
    [ -e "$p" ] || { echo "✗ $claude_md points at a path that no longer exists: $p"; fail=1; }
  done < <(grep -oE '(^|[[:space:]`(])/[A-Za-z0-9._/-]+\.md' "$claude_md" | sed 's|^[^/]*||' | sort -u)
  read_targets="$read_targets absolute-pointers"
else
  skipped="$skipped absolute-pointers(no assistant instructions here)"
fi

# 4 — the hooks: a LOCAL file outside any repo, and an undeclared hook never fires. Which lines of
#     the table are hooks is DEDUCED (their gate cell reads "n/a"), never hard-coded here.
settings="$HOME/.claude/settings.json"
table=docs/repo-controls.md
if [ -f "$settings" ] && [ -f "$table" ]; then
  hooks=$(grep -oE '^\| `checks/(verify-[a-z-]+)\.sh`.*\| n/a' "$table" | grep -oE 'verify-[a-z-]+' || true)
  if [ -n "$hooks" ]; then
    declared=0 missing=""
    for h in $hooks; do
      if grep -q "$h" "$settings"; then declared=$((declared + 1)); else missing="$missing $h"; fi
    done
    # All or nothing: none declared is the documented inactive mode, not an error. SOME declared
    # and others not is the dangerous shape — the hooks are in use, and one stopped being.
    if [ "$declared" -gt 0 ] && [ -n "$missing" ]; then
      echo "✗ hooks wired in $settings, but NOT these:$missing — they exist and never fire"
      fail=1
    fi
    read_targets="$read_targets hooks"
  else
    skipped="$skipped hooks(the table declares none)"
  fi
else
  skipped="$skipped hooks(no assistant settings or no control table here)"
fi

# The verdict names what was READ and what was NOT: verify-do-not-break.md.
if [ "$fail" = 0 ]; then
  if [ -n "$read_targets" ]; then
    echo "✓ nothing quietly unplugged — read:$read_targets"
  else
    echo "✓ nothing to check here — none of the four targets exists in this project"
  fi
  if [ -n "$skipped" ]; then echo "  NOT read:$skipped"; fi
fi
exit "$fail"
