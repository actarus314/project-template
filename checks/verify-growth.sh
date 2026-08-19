#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   tags: 2   (what this does with a verdict; compared to the control table AND to its real exit code)
# A curated document that only ever grows — forbidden by METHODE: the hot side SHRINKS when a
# stage closes. TWO halves, one observable event each:
#   · repo/       — a .md grown by a percentage since the last release. Weak, and measured so.
#   · workspace/  — a stage CLOSED (an archive directory is born) with no pruning. No threshold.
# 🔴 Detected, never listed; what accumulates by nature is excluded. docs/code/verify-growth.md.

set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# Adjustable, DISJOINT populations: the floor governs what is under 4x itself (verify-growth.md).
# A TAG per rule: it is what reaches the journal, and CHECK_TAGS is absent outside check.sh.
tag() { [ -n "${CHECK_TAGS:-}" ] && printf '%s\n' "$1" >>"$CHECK_TAGS"; return 0; }
THRESHOLD=${GROWTH_THRESHOLD:-15}
FLOOR=${GROWTH_FLOOR:-1500}
COMPARED=0; NEWBORN=0

# The tag gates the repo/ half ALONE. Exiting here would also skip the workspace half, which needs
# no release: a project closes its first stage long before it publishes one.
tag=$(git describe --tags --abbrev=0 2>/dev/null || true)

grown=0

# FOUR bulk calls, whatever the file count; the join is in awk (bash 3.2 has no assoc. arrays).
# 🔴 `grep -c ''` on BOTH sides, and the list filtered in the shell — why, and the two routes
#   rejected: docs/code/verify-growth.md.
compare_tree() {         # <repository> <revision> <label> <ERE selecting the curated documents>
  local dir="$1" rev="$2" label="$3" select="$4"
  local T; T=$(mktemp -d)
  git -C "$dir" ls-tree -r --name-only "$rev" \
    | grep -E "$select" | grep -vE "$EXCLUDE" > "$T/paths" || true
  # A document born since the tag has NO reference, so it cannot grow by any percentage — it is
  # invisible to this check by construction, at any size. Counted and said, never left silent.
  git -C "$dir" ls-files | grep -E "$select" | grep -vE "$EXCLUDE" | sort > "$T/today" || true
  newborn=$(comm -23 "$T/today" <(sort "$T/paths") | wc -l | tr -d ' ')
  NEWBORN=$((NEWBORN + newborn))
  COMPARED=$((COMPARED + $(grep -c '' "$T/paths" || true)))
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

  awk -v label="$label" -v threshold="$THRESHOLD" -v floor="$FLOOR" '
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
        # Below the floor the percentage does not decide — it is harshest on the smallest document.
        if (worst >= threshold + 0 && nowb[p] - revb[p] >= floor + 0) {
          printf "  ↑ %-32s %4d → %4d lines (%+d%%), %6d → %6d bytes (%+d%%)\n",
                 label p, revl[p], nowl[p], pl, revb[p], nowb[p], pb
          n++
        }
      }
      exit (n > 0)
    }' "$T/live" "$T/rev-bytes" "$T/rev-lines" "$T/now-lines" "$T/now-bytes" || { tag document-only-grows; grown=1; }
  rm -rf "$T"
}

# 🔴 DETECTED, never listed — every tracked `.md`, minus what accumulates by nature (a CHANGELOG,
# an archive, a GENERATED page). Same exclusions as verify-echo.sh: one rule, one set of documents.
EXCLUDE='(^|/)(CHANGELOG\.md$|archives?/|\.github/|CONTROLES\.md$)'
if [ -n "$tag" ]; then
  compare_tree . "$tag" "" '\.md$'
else
  echo "  (repo/: no release yet — the percentage half has no reference)"
fi

# ── The workspace half: a closing stage must make the hot side shrink ────────────────────────
# The workspace is a separate repository with no remote and no tag, and it is optional: a generated
# project can be created without it.

# The HOT SIDE is every tracked `.md` outside archives/ — a ROLE, never a file name: METHODE states
# the tracking document is a default, and a project driven by GSD or Linear names it otherwise.
# Splitting on TAB is load-bearing: `ls-tree -l` puts the size in field 4 of the first part and the
# path after the tab, so a path containing a space cannot shift the size column.
hot_bytes() {            # <repository> <revision, or WORKTREE>
  local dir="$1" rev="$2"
  if [ "$rev" = WORKTREE ]; then
    ( cd "$dir" && git ls-files -z -- '*.md' | xargs -0 wc -c 2>/dev/null ) \
      | awk '$2 != "total" && $2 !~ /(^|\/)archives\// { s += $1 } END { print s + 0 }'
  else
    git -C "$dir" ls-tree -r -l "$rev" 2>/dev/null \
      | awk -F'\t' '{ split($1, f, " ")
                      if ($2 ~ /\.md$/ && $2 !~ /(^|\/)archives\//) s += f[4] } END { print s + 0 }'
  fi
}

# The archive DIRECTORY is the signal, never a file named inside it: a stage can be closed by a
# dated report and carry no SYNTHESE.md at all, and a guard keyed on that name stays silent on
# exactly the case it exists for. (Which archive proves it: docs/code/verify-growth.md.)
# ONE expression, used by both readings below — two copies of it would drift.
TO_DIR='s|^\(.*archives/[^/]*\)/.*|\1|p'
archive_dirs() { sed -n "$TO_DIR" | sort -u; }   # paths on stdin → one archive directory per line

if [ -d ../workspace/.git ]; then
  ws=../workspace
  scope="repo/ and workspace/"

  # A closure being written RIGHT NOW is the moment this guard is useful, and it has not been
  # committed yet — the workspace carries no hook, so nothing else will look.
  born_worktree=$( { git -C "$ws" ls-files --cached --others --exclude-standard; } | archive_dirs)
  born_head=$(git -C "$ws" ls-tree -r --name-only HEAD 2>/dev/null | archive_dirs)
  pending=$(comm -23 <(printf '%s\n' "$born_worktree") <(printf '%s\n' "$born_head"))
  # A RENAMED archive is not a BORN one, and git is what tells them apart. Read as a birth, three
  # folders gaining a date prefix asked the hot side to shrink for stages closed months earlier.
  renamed=$(git -C "$ws" diff --cached -M --diff-filter=R --name-only 2>/dev/null | archive_dirs)
  [ -z "$renamed" ] || pending=$(comm -23 <(printf '%s\n' "$pending") <(printf '%s\n' "$renamed"))

  if [ -n "$pending" ]; then
    before=$(hot_bytes "$ws" HEAD); after=$(hot_bytes "$ws" WORKTREE)
    what="$(printf '%s' "$pending" | tr '\n' ' ') — uncommitted"
  else
    # Otherwise: the LAST closure already committed. Read oldest-first and keep each directory's
    # FIRST appearance — that commit is its birth; the last line is the most recent birth.
    birth=$(git -C "$ws" log --reverse --diff-filter=A --format='@%H' --name-only -- '*archives/*' \
            | sed -n -e '/^@/p' -e "$TO_DIR" \
            | awk '/^@/ { h = substr($0, 2); next }
                   !($0 in seen) { seen[$0] = 1; print h, $0 }' \
            | tail -1)
    if [ -n "$birth" ]; then
      rev=${birth%% *}; what=${birth#* }
      # A closure is a GESTURE, not a commit: the archive is born in one, the hot side is pruned
      # in the next. Reading the state AT the birth froze "after" before the pruning existed, so a
      # correct closure was reported as a growth — the shape that gets a guard switched off.
      # Reading it at HEAD moves the same fault one step on: the NEXT stage legitimately reopens
      # work, and the guard then bites a closure that did prune. So the question is whether the hot
      # side EVER dropped below its pre-closure size — a fact, settled once, and never a threshold.
      before=$(hot_bytes "$ws" "$rev^"); after=$(hot_bytes "$ws" HEAD)
      for rv in $(git -C "$ws" rev-list --reverse "$rev^..HEAD"); do
        [ "$after" -lt "$before" ] && break
        m=$(hot_bytes "$ws" "$rv"); [ "$m" -lt "$after" ] && after=$m
      done
    fi
  fi

  if [ -z "${before:-}" ] || [ "$before" = 0 ]; then
    # Zero targets reads exactly like a clean tree — so it is said, never passed off as a verdict.
    echo "  (workspace/: no closed stage to compare — no archive directory born under git)"
  elif [ "$after" -lt "$before" ]; then
    echo "  ✓ workspace/: the last closure pruned the hot side — $what, $before → $after bytes at its lowest"
  else
    printf '  ↑ %-32s %6d → %6d bytes (%+d) — a stage closed and the hot side did NOT shrink\n' \
           "workspace/ $what" "$before" "$after" "$((after - before))"
    tag closure-without-pruning
    grown=1
  fi
else
  # Said out loud: the verdict used to claim "in either repository" with the neighbour absent.
  echo "  (no ../workspace/.git beside this repo — repo/ only)"
  scope="repo/ only"
fi

born=""; [ "$NEWBORN" -gt 0 ] && born=" · $NEWBORN born since the tag, NOT comparable"
[ "$grown" = 0 ] && echo "✓ nothing grew unchecked — $scope; read: $COMPARED document(s) against ${tag:-no tag}$born"
if [ "$grown" != 0 ]; then
  cat >&2 <<'MSG'
  Prune the WHOLE document, not only what this branch added: the newest section is rarely the
  fattest, and trimming that alone leaves the new part thin and the old part fat.
  Each cut is one of two decisions, and they are not the same: what should never have been written
  here is DELETED outright; what earns its keep MOVES to the file that owns it — rewritten if the
  new home calls for it. Neither is the default: the choice is made per passage.
MSG
fi
exit "$grown"   # blocking: same reason
