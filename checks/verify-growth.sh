#!/usr/bin/env bash
# Curated documents that only ever GROW.
#
# METHODE says the main documents stay short, and that a stage's closure makes the tracking doc
# SHRINK: it grows while a stage runs, then gets pruned. A document no one rereads is useless, and
# a runbook that has become unreadable goes unread — after which the action gets done from memory.
#
# Concision is a rule of METHOD, not one of published style, so it follows the method into the
# neighbouring workspace — where the very document METHODE names as the one that must shrink lives.
# Archives are left out on purpose: they are the cold side, and METHODE states that too many
# archive files is not a problem.
#
# An absolute size would be arbitrary: repo-controls.md is legitimately long, it absorbed four
# sections. What IS observable is a document that grows and never comes back down. So the
# comparison is against the last RELEASE, not against a number someone picked.
#
# The workspace carries no tag, so what crosses over is the release TIMESTAMP: both repositories
# advance on the same undertaking, and its last commit strictly before that instant is the same
# reference point. Reaching for a tag that does not exist there would print "no release yet" and
# pass in silence — a guard fails by passing, not by shouting.
#
# Both bytes AND lines are compared: the curated documents run from 57 to 175 bytes per line, so a
# document written one sentence per line can swell by half in bytes without moving a single line.
#
# ADVISORY: growth is often legitimate (a subject arrives). What this makes impossible is growing
# without noticing — and being unable to say, at closing time, what actually breathed.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

THRESHOLD=${GROWTH_THRESHOLD:-25}

tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
[ -n "$tag" ] || { echo "  (no release yet — nothing to compare against)"; exit 0; }
released_at=$(git log -1 --format=%cI "$tag")

grown=0

# `grep -c ''` on both sides so both count the same thing: `wc -l` counts newlines, and misses a
# last line with no final newline. Looped over rather than indexed — /bin/bash 3.2, which ships
# with macOS, has no associative arrays.
#
# The file list is filtered in the shell rather than through a pathspec: `ls-tree` matches a
# pathspec literally, so `docs/*.md` selects nothing, and it rejects `:(exclude)` outright. Both
# failures are empty output, which reads exactly like a clean tree.
compare_tree() {         # <repository> <revision> <label> <ERE selecting the curated documents>
  local dir="$1" rev="$2" label="$3" select="$4"
  local listing f before_l before_b now_l now_b pct_l pct_b worst
  listing=$(git -C "$dir" ls-tree -r --name-only "$rev")   # unmuzzled: a failure here must shout
  while IFS= read -r f; do
    [ -f "$dir/$f" ] || continue                  # deleted since that point: nothing to compare
    before_l=$(git -C "$dir" show "$rev:$f" | grep -c '' || true)
    before_b=$(git -C "$dir" cat-file -s "$rev:$f")
    [ "$before_l" -gt 0 ] && [ "$before_b" -gt 0 ] || continue
    now_l=$(grep -c '' "$dir/$f" || true)
    now_b=$(wc -c < "$dir/$f" | tr -d ' ')
    pct_l=$(( (now_l - before_l) * 100 / before_l ))
    pct_b=$(( (now_b - before_b) * 100 / before_b ))
    worst=$pct_l; [ "$pct_b" -gt "$worst" ] && worst=$pct_b
    if [ "$worst" -ge "$THRESHOLD" ]; then
      printf '  ↑ %-32s %4d → %4d lines (%+d%%), %6d → %6d bytes (%+d%%)\n' \
        "$label$f" "$before_l" "$now_l" "$pct_l" "$before_b" "$now_b" "$pct_b"
      grown=1
    fi
  done < <(printf '%s\n' "$listing" | grep -E "$select" || true)
}

compare_tree . "$tag" "" '^(docs/[^/]+\.md|README\.md|AGENTS\.md|CONTRIBUTING\.md)$'

# The workspace is a separate repository with no remote and no tag, and it is optional: a generated
# project can be created without it.
if [ -d ../workspace/.git ]; then
  ws_rev=$(git -C ../workspace rev-list -1 --before="$released_at" HEAD 2>/dev/null || true)
  if [ -n "$ws_rev" ]; then
    # Root and docs/ only — which is where the tracking doc lands, whether this workspace or a
    # generated one. It leaves out archives/ by construction: they are the cold side, and METHODE
    # states that too many archive files is not a problem.
    compare_tree ../workspace "$ws_rev" "workspace/" '^([^/]+|docs/[^/]+)\.md$'
  else
    echo "  ⚠ workspace: no commit predates $tag — nothing to compare against"
    grown=1
  fi
fi

[ "$grown" = 0 ] && echo "✓ no curated document grew by ${THRESHOLD}% since $tag, in either repository"
exit 0        # advisory, never blocking
