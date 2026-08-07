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

# `--merged main` is the WRONG test here and stays out: this repository squash-merges, so a merged
# branch is never an ancestor of main and that test returns nothing (measured at #117, #119, #120).
gone=$(git branch -vv | grep ': gone]' | awk '{print $1}' | tr -d '*' || true)
[ -n "$gone" ] || { echo "✓ no dead local branch — read: every local branch's upstream"; exit 0; }

deleted=0; kept=0
for b in $gone; do
  case "$b" in main|develop) echo "  ⚠ $b — protected name, left alone"; kept=$((kept+1)); continue;; esac
  if [ "$b" = "$current" ]; then echo "  ⚠ $b — currently checked out, left alone"; kept=$((kept+1)); continue; fi

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

echo "✓ ${deleted} deleted, ${kept} kept — read: $(echo "$gone" | grep -c .) branch(es) whose upstream is gone, each checked against its pull request"
