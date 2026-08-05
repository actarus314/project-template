#!/usr/bin/env bash
# Curated documents that only ever GROW.
#
# Scripts are NOT here: a comment outgrowing its code is a different question, asked at a
# different moment and answered from a different target, so it lives in its own check.
# Keeping both under one roof produced a defect within the hour — gating the pair on prose
# blinded the script half exactly on a commit that touched only scripts.
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
# BLOCKING. Growth is often legitimate (a subject arrives), and this header called itself advisory
# long after that stopped being true — the threshold was settled on measurement and the check was
# made to block, while this line went on saying otherwise. What it makes impossible is growing
# without noticing, and being unable to say, at closing time, what actually breathed.
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
# last line with no final newline. Awk counts RECORDS below, which is the same semantics.
#
# The file list is filtered in the shell rather than through a pathspec: `ls-tree` matches a
# pathspec literally, so `docs/*.md` selects nothing, and it rejects `:(exclude)` outright. Both
# failures are empty output, which reads exactly like a clean tree.
#
# 🔴 FOUR calls, whatever the file count. This used to fork `git show` AND `git cat-file -s` once
# per document — measured at 585 ms of pure process startup for 24 files, the single dominant cost
# of this check, against 40 ms for the four bulk calls that replace them. `git cat-file --batch`
# was the obvious route and was rejected: its stream interleaves headers with raw bytes, and no awk
# can skip a byte count, so a file with no trailing newline shifts every object after it.
# The join happens in awk because /bin/bash 3.2, which macOS ships, has no associative arrays.
compare_tree() {         # <repository> <revision> <label> <ERE selecting the curated documents>
  local dir="$1" rev="$2" label="$3" select="$4"
  local T; T=$(mktemp -d)
  git -C "$dir" ls-tree -r --name-only "$rev" \
    | grep -E "$select" | grep -vE "$EXCLUDE" > "$T/paths" || true
  # Deleted since that point: nothing to compare, and it must not reach the bulk readers either.
  : > "$T/live"
  while IFS= read -r f; do [ -f "$dir/$f" ] && printf '%s\n' "$f" >> "$T/live"; done < "$T/paths"
  [ -s "$T/live" ] || { rm -rf "$T"; return 0; }

  git -C "$dir" ls-tree -r -l "$rev"  > "$T/rev-bytes" 2>/dev/null || true
  git -C "$dir" grep -c '' "$rev"     > "$T/rev-lines" 2>/dev/null || true
  # `-H` is load-bearing: with a SINGLE file grep prints the bare count and drops the name, which
  # would make the join silently attribute that count to nothing at all.
  ( cd "$dir" && tr '\n' '\0' < "$T/live" | xargs -0 grep -cH '' ) > "$T/now-lines" 2>/dev/null || true
  ( cd "$dir" && tr '\n' '\0' < "$T/live" | xargs -0 wc -c )       > "$T/now-bytes" 2>/dev/null || true

  awk -v label="$label" -v threshold="$THRESHOLD" '
    function pct(now, before) { return int((now - before) * 100 / before) }
    FNR == 1 { stage++ }
    stage == 1 { live[$0] = 1; next }                                  # live
    stage == 2 { p = $0; sub(/^[^\t]*\t/, "", p)                        # rev-bytes
                 split($0, h, "\t"); split(h[1], f, " ")
                 if (p in live) revb[p] = f[4]; next }
    stage == 3 { line = $0; i = index(line, ":"); line = substr(line, i + 1)   # rev-lines
                 j = length(line); while (j > 0 && substr(line, j, 1) != ":") j--
                 p = substr(line, 1, j - 1); c = substr(line, j + 1)
                 if (p in live) revl[p] = c + 0; next }
    stage == 4 { line = $0                                              # now-lines
                 j = length(line); while (j > 0 && substr(line, j, 1) != ":") j--
                 p = substr(line, 1, j - 1); c = substr(line, j + 1)
                 if (p in live) nowl[p] = c + 0; next }
    stage == 5 { if ($NF == "total") next                               # now-bytes
                 c = $1; p = $0; sub(/^[ \t]*[0-9]+[ \t]+/, "", p)
                 if (p in live) nowb[p] = c + 0; next }
    END {
      n = 0
      for (p in live) {
        if (!(p in revl) || !(p in revb) || !(p in nowl) || !(p in nowb)) continue
        if (revl[p] <= 0 || revb[p] <= 0) continue
        pl = pct(nowl[p], revl[p]); pb = pct(nowb[p], revb[p])
        worst = (pb > pl) ? pb : pl
        if (worst >= threshold + 0) {
          printf "  ↑ %-32s %4d → %4d lines (%+d%%), %6d → %6d bytes (%+d%%)\n",
                 label p, revl[p], nowl[p], pl, revb[p], nowb[p], pb
          n++
        }
      }
      exit (n > 0)
    }' "$T/live" "$T/rev-bytes" "$T/rev-lines" "$T/now-lines" "$T/now-bytes" || grown=1
  rm -rf "$T"
}

# 🔴 DETECTED, never listed. It used to name `docs/*.md` plus three files at the root, which
# presumes a project keeps its prose where this one does: a project writing into `documentation/`
# or `guide/` was invisible to it. Every tracked `.md` is compared now, minus what accumulates by
# nature — a CHANGELOG, an archive, a form template. Same exclusions as verify-echo.sh: concision
# is one rule, and two checks reading two different sets of documents would be two answers to it.
EXCLUDE='(^|/)(CHANGELOG\.md$|archives?/|\.github/)'
compare_tree . "$tag" "" '\.md$'

# The workspace is a separate repository with no remote and no tag, and it is optional: a generated
# project can be created without it.
if [ -d ../workspace/.git ]; then
  ws_rev=$(git -C ../workspace rev-list -1 --before="$released_at" HEAD 2>/dev/null || true)
  if [ -n "$ws_rev" ]; then
    # Root and docs/ only — which is where the tracking doc lands, whether this workspace or a
    # generated one. It leaves out archives/ by construction: they are the cold side, and METHODE
    # states that too many archive files is not a problem.
    compare_tree ../workspace "$ws_rev" "workspace/" '\.md$'
  else
    echo "  ⚠ workspace: no commit predates $tag — nothing to compare against"
    grown=1
  fi
  scope="repo/ and workspace/"
else
  # Said out loud: the verdict used to claim "in either repository" with the neighbour absent.
  echo "  (no ../workspace/.git beside this repo — repo/ only)"
  scope="repo/ only"
fi

[ "$grown" = 0 ] && echo "✓ no curated document grew by ${THRESHOLD}% since $tag — $scope"
exit "$grown"   # blocking: same reason
