#!/usr/bin/env bash
# blocking: no   (what this does with a verdict; compared to the control table AND to its real exit code)
# What an agent's work leaves behind, and what it is worth — advisory (why: verify-leftovers.md).
# TWO halves, and neither is covered elsewhere: a local branch with no upstream, and a worktree
# directory git never registered. Two verdicts on the first, never one: content already on the
# server (bin it, nothing to lose) against content found nowhere (it is the only copy).
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 || { echo "  (not a git repository — nothing to read)"; exit 0; }

said=0; branch_read="no remote-tracking ref, so no branch could be judged"

# ── Half one: the branch nobody ever pushed ──────────────────────────────────────────────────────
mapfile -t REMOTES < <(git for-each-ref --format='%(refname:short)' refs/remotes/ 2>/dev/null | grep -v '/HEAD$' || true)
if [ "${#REMOTES[@]}" -gt 0 ]; then
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
  branch_read="$(git for-each-ref refs/heads/ | grep -c .) local branch(es) against ${#REMOTES[@]} remote-tracking ref(s), patch-id against $default${skipped:+; $skipped is checked out, left alone}"
fi

# ── Half two: the worktree directory git never registered ────────────────────────────────────────
# What the NATIVE tools already cover, and where they stop: an unchanged worktree is cleaned up by
# the harness itself, and `git worktree prune` drops the dead ENTRIES. Neither removes a directory
# that was modified and was never registered — invisible to `worktree list` and to `prune` alike.
WT=.claude/worktrees
dir_read="no $WT/ here"
if [ -d "$WT" ]; then
  registered=$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' || true)
  stray=""; n_dirs=0; n_known=0
  for d in "$WT"/*/; do
    [ -d "$d" ] || continue
    n_dirs=$((n_dirs + 1))
    abs=$(cd "$d" && pwd -P)
    # Counted against the directories, never against `worktree list`, whose first line is the
    # repository ITSELF: "1 registered" would read as one live worktree where there are none.
    printf '%s\n' "$registered" | grep -qxF "$abs" && { n_known=$((n_known + 1)); continue; }
    # `du` runs on the strays ONLY: it walks the tree, and these hold node_modules. A repository
    # with nothing left behind pays nothing for this half.
    stray="$stray $(basename "$d")($(du -sm "$d" 2>/dev/null | cut -f1) MB)"
  done
  if [ -n "$stray" ]; then
    echo "⚠ worktree directories git does not know about —$stray"
    echo "  (neither the harness nor \`git worktree prune\` removes these: check the content is on the"
    echo "   server, then delete the directory)"
    said=1
  fi
  dir_read="$n_dirs directory(ies) under $WT/, $n_known of them a live worktree"
fi

# Sizes and ages are PUBLISHED and never judged: no measurement here says when a dormant branch or a
# leftover directory becomes a problem, and a threshold picked to look reasonable is refused.
if [ "$said" -eq 0 ]; then
  echo "✓ nothing left behind — read: $branch_read; $dir_read"
else
  echo "  (advisory — the gate stays green: work not pushed yet is ordinary, and only the maintainer"
  echo "   knows which of these is which. Read: $branch_read; $dir_read.)"
fi
exit 0
