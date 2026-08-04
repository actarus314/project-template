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

# The same question asked of the SCRIPTS: is the comment swelling faster than the code it explains?
#
# An absolute ratio would be meaningless here. These scripts sit at 28-56% comment, far above what
# general-purpose tools recommend, and deliberately so: the rule is that a comment carries the WHY.
# What is observable is the DIFFERENCE between the two growth rates — measured across this repo's
# releases, it sits at a median of 0 and a 95th percentile of +6, with exactly one real outlier at
# +149 (check.sh gaining 196% comment for 47% code). Hence a threshold well above the noise and
# well below the one case that matters.
COMMENT_DRIFT=${COMMENT_DRIFT_THRESHOLD:-40}

count_pair() {           # <revision|--worktree> <path>  ->  "<comments> <code>", empty if absent
  # The current side is read from DISK, not from HEAD: comparing two commits would only ever see a
  # comment that has already been committed, so the check could not speak while the file is being
  # written — which is the only moment it is useful.
  #
  # The `|| true` is load-bearing under `pipefail`: a file that did not exist at that revision
  # makes `git show` fail, which would otherwise take the whole script down mid-loop.
  { if [ "$1" = "--worktree" ]; then cat "$2" 2>/dev/null || true
    else git show "$1:$2" 2>/dev/null || true; fi; } | awk '
    { line=$0; sub(/^[ \t]+/,"",line)
      if (line == "") next
      if (line ~ /^#/) c++; else k++ }
    END { if (c+k > 0) print c, k }'
}

while IFS= read -r f; do
  [ -f "$f" ] || continue
  before=$(count_pair "$tag" "$f"); [ -n "$before" ] || continue
  com0=${before% *}; code0=${before#* }
  # Below this size a single added line moves the percentage by tens of points, which is noise.
  [ "$code0" -ge 15 ] && [ "$com0" -ge 5 ] || continue
  now=$(count_pair --worktree "$f"); [ -n "$now" ] || continue
  com1=${now% *}; code1=${now#* }
  d_code=$(( (code1 - code0) * 100 / code0 ))
  d_com=$(( (com1 - com0) * 100 / com0 ))
  if [ $(( d_com - d_code )) -ge "$COMMENT_DRIFT" ]; then
    printf '  ↑ %-32s comment %+d%%, code %+d%% since %s — the WHY is outgrowing the what\n' \
      "$f" "$d_com" "$d_code" "$tag"
    grown=1
  fi
done < <(git ls-tree -r --name-only HEAD | grep -E '\.sh$' || true)

[ "$grown" = 0 ] && echo "✓ no curated document grew by ${THRESHOLD}%, no script comment outgrew its code, since $tag"
exit 0        # advisory, never blocking
