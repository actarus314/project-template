#!/usr/bin/env bash
# Deletes a local branch ONLY when both conditions hold: its remote is gone, AND its pull request
# reads MERGED. The pass calls this instead of running the gestures itself — a skill is text, so
# nothing proves it checked; here the proof is the code, and every branch examined is printed with
# the verdict that decided it.
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

git rev-parse --git-dir >/dev/null 2>&1 || { echo "✗ not a git repository"; exit 1; }
slug=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]##; s#\.git$##' || true)
[ -n "$slug" ] || { echo "  (no origin remote — nothing to check a pull request against)"; exit 0; }

git fetch --prune --quiet 2>/dev/null || echo "  ⚠ fetch failed — the list below may be stale"
current=$(git branch --show-current 2>/dev/null || true)
# One reference for patch-id, as the server names its default branch. Running `git cherry` against
# every remote ref instead is what would make this quadratic on a repository with many of them.
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
[ -n "$DEFAULT" ] || for c in origin/main origin/master; do
  git rev-parse --verify --quiet "$c" >/dev/null 2>&1 && { DEFAULT=$c; break; }
done

# `--merged main` is the WRONG test here and stays out: this repository squash-merges, so a merged
# branch is never an ancestor of main and that test returns nothing (measured at #117, #119, #120).
gone=$(git branch -vv | grep ': gone]' | awk '{print $1}' | tr -d '*' || true)

# A branch that NEVER had an upstream satisfies neither condition above. Its own test is a THIRD
# one, reading the CONTENT rather than the server's branch state: docs/code/verify-leftovers.md.
orphan=$(git for-each-ref --format='%(refname:short)%09%(upstream:short)' refs/heads/ |
         awk -F'\t' 'NF<2 || $2==""{print $1}' || true)
[ -n "$gone$orphan" ] || { echo "✓ no dead local branch — read: every local branch's upstream"; exit 0; }

deleted=0; kept=0
for b in $gone $orphan; do
  case "$b" in main|develop) echo "  ⚠ $b — protected name, left alone"; kept=$((kept+1)); continue;; esac
  if [ "$b" = "$current" ]; then echo "  ⚠ $b — currently checked out, left alone"; kept=$((kept+1)); continue; fi

  # Which of the two routes this branch came in by decides which proof it owes.
  if printf '%s\n' $orphan | grep -qx "$b"; then
    # `|| true` is load-bearing: without it `set -e` kills the script mid-list on the ordinary case
    # — no remote ref contains this branch (docs/code/verify-leftovers.md).
    reached=$(for r in $(git for-each-ref --format='%(refname:short)' refs/remotes/ | grep -v '/HEAD$'); do
                git merge-base --is-ancestor "$b" "$r" 2>/dev/null && { echo "$r"; break; }; done || true)
    if [ -z "$reached" ] && [ -z "$(git cherry "$DEFAULT" "$b" 2>/dev/null | grep '^+' || true)" ]; then
      reached="$DEFAULT (patch-id)"
    fi
    if [ -z "$reached" ]; then
      echo "  ⚠ $b — never pushed, and its content is on NO remote ref → kept (it is the only copy)"
      kept=$((kept+1)); continue
    fi
    if [ "$DRY" = 1 ]; then echo "  · $b — would delete (never pushed, content reachable from $reached)"
    else git branch -D "$b" >/dev/null && echo "  ✓ $b — deleted (never pushed, content reachable from $reached)"; fi
    deleted=$((deleted+1)); continue
  fi

  # The SECOND condition, and it is the whole point: `: gone]` says the remote disappeared, never
  # that the work landed. A branch deleted by hand on the forge prints exactly the same thing.
  n=$(gh pr list --head "$b" --state merged --repo "$slug" --json number --jq 'length' 2>/dev/null || echo "?")
  case "$n" in
    ""|"?"|0) echo "  ⚠ $b — remote gone, but NO merged pull request found (read: gh pr list --state merged) → kept"
              kept=$((kept+1)) ;;
    *)        if [ "$DRY" = 1 ]; then echo "  · $b — would delete (remote gone + $n merged PR)"
              else git branch -D "$b" >/dev/null && echo "  ✓ $b — deleted (remote gone + $n merged PR)"; fi
              deleted=$((deleted+1)) ;;
  esac
done

echo "✓ ${deleted} deleted, ${kept} kept — read: $(printf '%s' "$gone" | grep -c . || true) branch(es) whose upstream is gone, each checked against its pull request; $(printf '%s' "$orphan" | grep -c . || true) never pushed, each checked against the content of every remote ref"
