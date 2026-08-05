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
# ADVISORY: growth is often legitimate. What this makes impossible is not noticing.
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

count_pair() {           # <repository> <revision|--worktree> <path> <marker> -> "<comments> <code>"
  # The current side is read from DISK, not from HEAD: comparing two commits would only ever see a
  # comment that has already been committed, so the check could not speak while the file is being
  # written — which is the only moment it is useful.
  #
  # The `|| true` is load-bearing under `pipefail`: a file that did not exist at that revision
  # makes `git show` fail, which would otherwise take the whole script down mid-loop.
  { if [ "$2" = "--worktree" ]; then cat "$1/$3" 2>/dev/null || true
    else git -C "$1" show "$2:$3" 2>/dev/null || true; fi; } | awk -v m="$4" 'BEGIN { c=0; k=0 }

    { line=$0; sub(/^[ \t]+/,"",line)
      if (line == "") next
      # A trailing comment counts as ONE of each: the line carries code AND comment. Counting
      # it as pure code was blind to the very shape that grows a comment invisibly.
      if (index(line, m) == 1) c++
      else if (index(line, m) > 1) { c++; k++ }
      else k++ }
    END { if (c+k > 0) print c, k }'
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

scan_tree() {            # <repository> <revision> <label>
  local dir="$1" rev="$2" label="$3"
  local unknown="" f marker before now com0 code0 com1 code1 d_code d_com added_com
  # Counted and published. "workspace/ and repo/" in a verdict says which trees the script INTENDED
  # to read; only a count says whether anything of its kind was actually there. Zero files with a
  # known marker is a legitimate answer — it is indistinguishable from "never read" unless said.
  local examined=0
  while IFS= read -r f; do
    [ -f "$dir/$f" ] || continue
    marker=$(marker_for "$f")
    if [ -z "$marker" ]; then
      # Prose and data carry no line comments — their absence is not a gap. Only an unrecognised
      # CODE extension is worth naming, since that one really is a language going unexamined.
      case "${f##*.}" in
        md|markdown|rst|txt|adoc|mdx|org|json|lock|csv|svg|png|jpg|ico|pdf|html|htm|css|scss) ;;
        *) case " $unknown " in *" ${f##*.} "*) ;; *) unknown="$unknown ${f##*.}";; esac;;
      esac
      continue
    fi
    examined=$(( examined + 1 ))
    before=$(count_pair "$dir" "$rev" "$f" "$marker"); [ -n "$before" ] || continue
    com0=${before% *}; code0=${before#* }
    # Below this size a single added line moves the percentage by tens of points, which is noise.
    [ "$code0" -ge 15 ] && [ "$com0" -ge 5 ] || continue
    now=$(count_pair "$dir" --worktree "$f" "$marker"); [ -n "$now" ] || continue
    com1=${now% *}; code1=${now#* }
    d_code=$(( (code1 - code0) * 100 / code0 ))
    d_com=$(( (com1 - com0) * 100 / com0 ))
    # 🔴 A FLOOR IN LINES, alongside the percentage gap. Percentages alone over-report a small file:
    # measured, +134% of comment against +94% of code was 34 added lines against 36 — the comment had
    # grown LESS than the code and the check still spoke. The floor is what a reader would call a
    # drift worth reading about, and it is what makes this one blocking rather than ignorable.
    added_com=$(( com1 - com0 ))
    if [ $(( d_com - d_code )) -ge "$COMMENT_DRIFT" ] && [ "$added_com" -ge "$COMMENT_MIN_LINES" ]; then
      printf '  ↑ %-32s comment %+d%%, code %+d%% since %s — the WHY is outgrowing the what\n' \
        "$label$f" "$d_com" "$d_code" "$rev"
      grown=1
    fi
  done < <(git -C "$dir" ls-tree -r --name-only HEAD | grep -E '\.[A-Za-z0-9]+$' || true)
  [ -n "$unknown" ] && echo "  ($label: extensions with no known comment marker, not examined:$unknown)"
  read_out="$read_out $label $examined file(s);"
  return 0
}
read_out=""

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
