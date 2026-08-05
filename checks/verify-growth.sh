#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A curated document that only ever grows — forbidden by METHODE: the hot side SHRINKS when a
# stage closes. Compared against the last release, in both repositories.
# 🔴 Documents are DETECTED, never listed; what accumulates by nature is excluded (a CHANGELOG,
# an archive, a GENERATED page). Why, and the exclusion list: docs/code/verify-growth.md.

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

# FOUR bulk calls, whatever the file count; the join is in awk (bash 3.2 has no assoc. arrays).
# 🔴 `grep -c ''` on BOTH sides, and the list filtered in the shell — why, and the two routes
#   rejected: docs/code/verify-growth.md.
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

# 🔴 DETECTED, never listed — every tracked `.md`, minus what accumulates by nature (a CHANGELOG,
# an archive, a GENERATED page). Same exclusions as verify-echo.sh: one rule, one set of documents.
EXCLUDE='(^|/)(CHANGELOG\.md$|archives?/|\.github/|CONTROLES\.md$)'
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
