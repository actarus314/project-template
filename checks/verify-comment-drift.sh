#!/usr/bin/env bash
# A script's comment growing faster than the code under it.
#
# METHODE says a comment carries only what the code cannot: the WHY, a constraint that would
# recur. A comment that keeps growing while the code does not is the shape that rule fails in —
# the doc's narrative migrating into the script, one paragraph at a time.
#
# An absolute ratio would say nothing here. These scripts sit at 28-56% comment, far above what
# general-purpose tools recommend, and deliberately so. What IS observable is the DIFFERENCE
# between the two growth rates, measured against the last release rather than a number someone
# picked. Across this repo's releases that difference has a median of 0 and a 95th percentile of
# +6, with exactly one real outlier at +149 — a script that gained 196% comment for 47% code.
# Hence a threshold well above the noise and well below the one case that mattered.
#
# 🔴 BOTH repositories, like its twin verify-narrative.sh. Concision and "a comment says only what
# the code cannot" are rules of METHOD, and METHODE's discriminator sends those into the
# neighbouring workspace/ too — unlike a rule of published style, which stops where publication
# stops. Reading repo/ alone was an exemption nothing justified, and one that would have gone on
# looking exactly like a clean result the day a script landed over there.
#
# The workspace carries no tag, so what crosses over is the release TIMESTAMP: both repositories
# advance on the same undertaking, and its last commit strictly before that instant is the same
# reference point. This is verify-growth.sh's parade, for the same reason.
#
# 🔴 The comment marker is looked up per LANGUAGE, not assumed to be `#`. This repo happens to be
# shell and python, but the check travels the same way the rule does, and a generated project may
# be TypeScript, Go or Rust — where a `#`-only reading would count zero comments and report a
# tidy "nothing to see" on a file that is 80% commentary.
#
# An extension nobody listed is NOT silently skipped: it is named at the end, per repository. A
# missing language would otherwise be a hole that looks exactly like a clean result.
#
# BLOCKING. Growth is often legitimate, and this header called itself advisory long after that
# stopped being true. What it makes impossible is not noticing.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
[ -n "$tag" ] || { echo "  (no release yet — nothing to compare against)"; exit 0; }
released_at=$(git log -1 --format=%cI "$tag")
grown=0

COMMENT_DRIFT=${COMMENT_DRIFT_THRESHOLD:-40}
# Added comment lines below which a percentage gap is an artefact of a small base.
COMMENT_MIN_LINES=${COMMENT_MIN_LINES:-20}

# 🔴 THREE calls per marker family per side, whatever the file count — not four forks per file.
# `git show | awk` and `cat | awk` cost 152 processes for 38 files. The three counts below are what
# the awk produced, expressed as patterns git can count in bulk:
#   A = non-empty lines            `[^[:space:]]`          (the awk skips lines empty after trim)
#   B = leading-comment lines      `^[[:space:]]*<marker>` (index(trimmed, marker) == 1)
#   C = lines holding the marker   fixed string            (leading OR trailing)
# and the awk's two totals follow: comments = C, code = A - B. A trailing comment counts once in
# each, which is exactly what C and A-B give it.
# `-e` on every pattern: a `--` marker is otherwise read as the end of the options.
# Every count is TAGGED as it is produced, and they all land in one file. Relying on argument
# ORDER instead breaks twice over: several marker families produce several files per kind, and a
# family with no match produces an EMPTY one that awk never opens — both shift every later count
# onto the wrong slot, silently.
emit() {                 # <tag> <strip-leading-rev> — normalises "rev:path:n" / "path:n" on stdin
  awk -v tag="$1" -v strip="$2" '{
    line = $0
    if (strip == "1") { j = index(line, ":"); line = substr(line, j + 1) }
    j = length(line); while (j > 0 && substr(line, j, 1) != ":") j--
    if (j > 0) printf "%s\t%s\t%s\n", tag, substr(line, 1, j - 1), substr(line, j + 1)
  }'
}
count_bulk() {           # <repository> <revision|--worktree> <marker> <list-file> <data-file>
  local dir="$1" rev="$2" m="$3" list="$4" data="$5"
  if [ "$rev" = "--worktree" ]; then
    # `-H` forces the name: with a single file grep prints the bare count and the join loses it.
    ( cd "$dir" && tr '\n' '\0' < "$list" | xargs -0 grep -cH  -e '[^[:space:]]' )    2>/dev/null | emit nA 0 >> "$data" || true
    ( cd "$dir" && tr '\n' '\0' < "$list" | xargs -0 grep -cH  -e "^[[:space:]]*$m" ) 2>/dev/null | emit nB 0 >> "$data" || true
    ( cd "$dir" && tr '\n' '\0' < "$list" | xargs -0 grep -cHF -e "$m" )              2>/dev/null | emit nC 0 >> "$data" || true
  else
    tr '\n' '\0' < "$list" | xargs -0 git -C "$dir" grep -c  -e '[^[:space:]]'    "$rev" -- 2>/dev/null | emit rA 1 >> "$data" || true
    tr '\n' '\0' < "$list" | xargs -0 git -C "$dir" grep -c  -e "^[[:space:]]*$m" "$rev" -- 2>/dev/null | emit rB 1 >> "$data" || true
    tr '\n' '\0' < "$list" | xargs -0 git -C "$dir" grep -cF -e "$m"              "$rev" -- 2>/dev/null | emit rC 1 >> "$data" || true
  fi
}

# extension -> line-comment marker. Whole families, not this project's two languages.
marker_for() {
  # Dotfiles and extensionless build files carry comments too, and `${f##*.}` gives them nothing
  # usable — matched by NAME first.
  case "$(basename "$1")" in
    .gitignore|.gitattributes|.envrc|.dockerignore|.editorconfig|Dockerfile*|Makefile|*.mk) echo '#'; return;;
  esac
  case "${1##*.}" in
    sh|bash|zsh|py|rb|pl|r|yml|yaml|toml|tf|nix|jl|ps1|cmake) echo '#';;
    js|mjs|cjs|jsx|ts|tsx|go|rs|java|kt|swift|c|h|cc|cpp|hpp|cs|scala|dart|php|proto|gradle) echo '//';;
    sql|hs|lua|elm|ada) echo '--';;
    el|lisp|clj|ini) echo ';';;
    *) echo '';;
  esac
}

read_out=""
scan_tree() {            # <repository> <revision> <label>
  local dir="$1" rev="$2" label="$3"
  local T; T=$(mktemp -d)
  local unknown="" f marker examined=0 i=0
  : > "$T/markers"; : > "$T/data"
  while IFS= read -r f; do
    [ -f "$dir/$f" ] || continue
    marker=$(marker_for "$f")
    if [ -z "$marker" ]; then
      case "${f##*.}" in
        md|markdown|rst|txt|adoc|mdx|org|json|lock|csv|svg|png|jpg|ico|pdf|html|htm|css|scss) ;;
        *) case " $unknown " in *" ${f##*.} "*) ;; *) unknown="$unknown ${f##*.}";; esac;;
      esac
      continue
    fi
    examined=$(( examined + 1 ))
    printf '%s\t%s\n' "$marker" "$f" >> "$T/markers"
  done < <(git -C "$dir" ls-tree -r --name-only HEAD | grep -E '\.[A-Za-z0-9]+$' || true)

  if [ "$examined" -gt 0 ]; then
    while IFS= read -r marker; do
      i=$(( i + 1 ))
      awk -F'\t' -v m="$marker" '$1==m {print $2}' "$T/markers" > "$T/list.$i"
      count_bulk "$dir" "$rev"     "$marker" "$T/list.$i" "$T/data"
      count_bulk "$dir" --worktree "$marker" "$T/list.$i" "$T/data"
    done < <(cut -f1 "$T/markers" | sort -u)

    awk -F'\t' -v label="$label" -v rev="$rev" -v drift="$COMMENT_DRIFT" -v minl="$COMMENT_MIN_LINES" '
      { v[$1 "\t" $2] = $3 + 0; if ($1 == "rA") seen[$2] = 1 }
      END {
        n = 0
        for (p in seen) {
          com0 = v["rC\t" p]; code0 = v["rA\t" p] - v["rB\t" p]
          com1 = v["nC\t" p]; code1 = v["nA\t" p] - v["nB\t" p]
          if (code0 < 15 || com0 < 5) continue
          dcode = int((code1 - code0) * 100 / code0)
          dcom  = int((com1  - com0)  * 100 / com0)
          if (dcom - dcode >= drift + 0 && com1 - com0 >= minl + 0) {
            printf "  ↑ %-32s comment %+d%%, code %+d%% since %s — the WHY is outgrowing the what\n",
                   label p, dcom, dcode, rev
            n++
          }
        }
        exit (n > 0)
      }' "$T/data" || grown=1
  fi

  [ -n "$unknown" ] && echo "  ($label: extensions with no known comment marker, not examined:$unknown)"
  read_out="$read_out $label $examined file(s);"
  rm -rf "$T"
  return 0
}

scan_tree . "$tag" "repo/"

# The workspace is a separate repository with no remote and no tag, and it is optional: a generated
# project can be created without it.
if [ -d ../workspace/.git ]; then
  ws_rev=$(git -C ../workspace rev-list -1 --before="$released_at" HEAD 2>/dev/null || true)
  if [ -n "$ws_rev" ]; then
    scan_tree ../workspace "$ws_rev" "workspace/"
    scope="repo/ and workspace/"
  else
    echo "  ⚠ workspace: no commit predates $tag — nothing to compare against"
    grown=1
    scope="repo/ only (workspace unreadable)"
  fi
else
  # Said out loud: a bare tick here would read exactly like a clean neighbour.
  echo "  (no ../workspace/.git beside this repo — repo/ only)"
  scope="repo/ only"
fi

[ "$grown" = 0 ] && echo "✓ no comment outgrew its code since $tag — $scope; read:$read_out"
exit "$grown"   # blocking: same reason
