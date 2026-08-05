#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
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
# Two of them live OUTSIDE the repository, so the CI has nothing to look at, and one is the
# generator's own — absent from every project this repo generates. Each target DETECTS whether it
# applies here; what is skipped is NAMED in the verdict, never folded into a bare tick. A guard that
# skips everything and prints a tick is worse than no guard, and a guard that DEMANDS a file the
# place cannot have is worse still: it fails where nothing is wrong.
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

# 1 — the skill is reached through a SYMLINK into this repository. A copy would drift, and drifting
#     copies of these recipes are what the anchoring was meant to end.
#     The link belongs to whichever repository HOLDS the skill. Every other one shares the machine
#     with it and must not be asked to account for it: without this condition, the link pointing at
#     the template — which is correct — failed every generated project on the same disk.
#     EVERY skill under skills/, detected rather than named. This was hard-coded to `new-project`
#     for as long as there was only one, and the second skill shipped with its link watched by
#     nothing — which is the failure mode that skill carries anyway: an unlinked skill does not
#     error, it simply never appears.
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

# 2 — the three files the neighbouring template .gitignore would otherwise swallow. They are
#     tracked through `git add -f`, so `git rm --cached` removes them without a word.
#     They exist only where the templates do: demanding them anywhere else fails a project for not
#     being the generator. The folder that holds them is the observable, so it is the condition.
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
  read_targets="$read_targets absolute-pointers"
else
  skipped="$skipped absolute-pointers(no assistant instructions here)"
fi

# 4 — the hooks. They are the only checks nothing else can see running: they live in the
#     assistant's settings, a LOCAL file outside any repository, and a hook that is not declared
#     simply never fires. No error, no output, no trace — the guard is gone and the session reads
#     exactly as it did before. Which of them are hooks is DEDUCED from the table (their gate cell
#     reads "n/a"), never listed here.
settings="$HOME/.claude/settings.json"
table=docs/repo-controls.md
if [ -f "$settings" ] && [ -f "$table" ]; then
  hooks=$(grep -oE '^\| `checks/(verify-[a-z-]+)\.sh`.*\| n/a' "$table" | grep -oE 'verify-[a-z-]+' || true)
  if [ -n "$hooks" ]; then
    declared=0 missing=""
    for h in $hooks; do
      if grep -q "$h" "$settings"; then declared=$((declared + 1)); else missing="$missing $h"; fi
    done
    # All or nothing. None declared is the documented inactive mode — a deliberate choice, and this
    # is not the place to argue with it. SOME declared and others not is the dangerous shape: the
    # hooks are in use, and one of them quietly stopped being.
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

# The verdict names what was READ and what was NOT. Four targets, each optional: a tick listing all
# four while three were skipped is the shape of green this repo has already been caught printing.
if [ "$fail" = 0 ]; then
  if [ -n "$read_targets" ]; then
    echo "✓ nothing quietly unplugged — read:$read_targets"
  else
    echo "✓ nothing to check here — none of the four targets exists in this project"
  fi
  if [ -n "$skipped" ]; then echo "  NOT read:$skipped"; fi
fi
exit "$fail"
