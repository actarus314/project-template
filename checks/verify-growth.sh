#!/usr/bin/env bash
# Curated documents that only ever GROW.
#
# METHODE says the main documents stay short, and that a stage's closure makes the tracking doc
# SHRINK: it grows while a stage runs, then gets pruned. A document no one rereads is useless, and
# a runbook that has become unreadable goes unread — after which the action gets done from memory.
#
# An absolute size would be arbitrary: repo-controls.md is legitimately long, it absorbed four
# sections. What IS observable is a document that grows and never comes back down. So the
# comparison is against the last RELEASE, not against a number someone picked.
#
# ADVISORY: growth is often legitimate (a subject arrives). What this makes impossible is growing
# without noticing — and being unable to say, at closing time, what actually breathed.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
[ -n "$tag" ] || { echo "  (no release yet — nothing to compare against)"; exit 0; }

grown=0
# Line counts at the tag in ONE git call instead of one `git show` per file, and its output IS the
# filter: a document absent at that tag never comes up. Looped over rather than indexed — /bin/bash
# 3.2, which ships with macOS, has no associative arrays. `grep -c ''` on both sides so both count
# the same thing: `wc -l` counts newlines, and misses a last line with no final newline.
while IFS=: read -r _ f before; do
  [ -f "$f" ] || continue                       # deleted since that tag: nothing to compare
  now=$(grep -c '' "$f" 2>/dev/null || echo 0)
  pct=$(( (now - before) * 100 / before ))
  if [ "$pct" -ge 25 ]; then
    printf '  ↑ %-46s %4d → %4d lines (+%d%%) since %s\n' "$f" "$before" "$now" "$pct" "$tag"
    grown=1
  fi
done < <(git grep -c '' "$tag" -- 'docs/*.md' README.md AGENTS.md CONTRIBUTING.md 2>/dev/null || true)

[ "$grown" = 0 ] && echo "✓ no curated document grew by 25% since $tag"
exit 0        # advisory, never blocking
