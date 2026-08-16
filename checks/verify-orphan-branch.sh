#!/usr/bin/env bash
# blocking: no   (what this does with a verdict; compared to the control table AND to its real exit code)
# A local branch with NO upstream, and what its content is worth — advisory (why: verify-orphan-branch.md).
# Two verdicts, never one: content already on the server (bin it, nothing to lose) against content
# found nowhere (it is the only copy). `prune-dead-branches.sh` reads the FIRST one to delete.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 || { echo "  (not a git repository — nothing to read)"; exit 0; }

mapfile -t REMOTES < <(git for-each-ref --format='%(refname:short)' refs/remotes/ 2>/dev/null | grep -v '/HEAD$' || true)
if [ "${#REMOTES[@]}" -eq 0 ]; then
  echo "  (no remote-tracking ref — every local branch is the only copy, and nothing here can tell one from another)"
  exit 0
fi

# The default branch as the server names it, with the two usual fallbacks. `git cherry` needs ONE
# reference, and running it against every remote ref is what makes this check quadratic.
default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
[ -n "$default" ] || for c in origin/main origin/master; do
  git rev-parse --verify --quiet "$c" >/dev/null 2>&1 && { default=$c; break; }
done
[ -n "$default" ] || default=${REMOTES[0]}

current=$(git branch --show-current 2>/dev/null || true)

contained=""; equivalent=""; alone=""; skipped=""
while read -r b; do
  [ -z "$b" ] && continue
  # The branch being WORKED ON is the legitimate case, and it is the whole reason this check stays
  # quiet: a guard that speaks on every commit of a branch not pushed yet gets disarmed.
  [ "$b" = "$current" ] && { skipped="$b"; continue; }

  reached=""
  for r in "${REMOTES[@]}"; do
    if git merge-base --is-ancestor "$b" "$r" 2>/dev/null; then reached=$r; break; fi
  done
  if [ -n "$reached" ]; then contained="$contained $b($reached)"; continue; fi

  # Squash turns the branch into a stranger to the graph while its CONTENT landed. patch-id sees
  # through that; a rebase that resolved a conflict changes the patch, and this stops seeing it.
  if [ -z "$(git cherry "$default" "$b" 2>/dev/null | grep '^+' || true)" ]; then
    equivalent="$equivalent $b"; continue
  fi

  n=$(git cherry "$default" "$b" 2>/dev/null | grep -c '^+' || true)
  age=$(( ( $(date +%s) - $(git log -1 --format=%at "$b") ) / 86400 ))
  alone="$alone $b($n commit(s), last touched ${age}d ago)"
done < <(git for-each-ref --format='%(refname:short)%09%(upstream:short)' refs/heads/ | awk -F'\t' 'NF<2 || $2==""{print $1}')

said=0
if [ -n "$contained$equivalent" ]; then
  echo "⚠ never pushed, and the server already holds the content —$contained$equivalent"
  # Named without its path: the pass that holds it does NOT travel, and a path that resolves only
  # here is a dead one in every generated project (verify-travel.sh catches exactly that).
  echo "  (nothing to lose — the closing pass deletes exactly these, on this same proof)"
  said=1
fi
if [ -n "$alone" ]; then
  echo "⚠ never pushed, and the content is found NOWHERE on the server —$alone"
  echo "  (this branch is the only copy there is: submit it, push it, or drop it deliberately)"
  said=1
fi

# The age is PUBLISHED and never judged: no measurement here says when a dormant branch becomes a
# problem, and a threshold picked to look reasonable is one this project refuses (verify-orphan-branch.md).
if [ "$said" -eq 0 ]; then
  echo "✓ no orphan branch left behind — read: $(git for-each-ref refs/heads/ | grep -c .) local branch(es) against ${#REMOTES[@]} remote-tracking ref(s), patch-id against $default${skipped:+; $skipped is checked out, left alone}"
else
  echo "  (advisory — the gate stays green: a branch not pushed yet is ordinary work, and only the"
  echo "   maintainer knows which of these is which. Read against $default${skipped:+; $skipped is checked out, left alone}.)"
fi
exit 0
