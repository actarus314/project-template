#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A comment growing faster than the code under it, sitting above a level, or running too long.
# Three limits: DRIFT since the last release, LEVEL (25 %) and longest BLOCK (6 lines); the last
# two apply to TOUCHED files only.
# 🔴 Thresholds, per-language marker, both repositories: docs/code/verify-comment-drift.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# The reference is the last MERGED pull request, never the last release: a far anchor re-judges
# work already merged green. Why that, and not "releases are rare": docs/code/verify-comment-drift.md.
# origin/main IS the last-merged state here, this repo being pull-request-only; falls back to the
# tag where there is no remote yet — hence a name that says reference, not release.
ref=$(git rev-parse --verify --quiet origin/main >/dev/null 2>&1 && echo origin/main \
      || git describe --tags --abbrev=0 2>/dev/null || true)
[ -n "$ref" ] || { echo "  (no reference point yet — nothing to compare against)"; exit 0; }
ref_at=$(git log -1 --format=%cI "$ref")
grown=0

COMMENT_DRIFT=${COMMENT_DRIFT_THRESHOLD:-40}
# Added comment lines below which a percentage gap is an artefact of a small base.
COMMENT_MIN_LINES=${COMMENT_MIN_LINES:-20}

# Three bulk `git grep` calls per marker family per side: A = non-empty lines, B = leading-comment
# lines, C = lines holding the marker. Comments are C, code is A - B.
# 🔴 Every count is TAGGED as it is produced — keying on argument ORDER shifts every later
#   count onto the wrong slot, silently. Why, and the cost it replaced: docs/code/verify-comment-drift.md.
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
  esac
  # ASK THE FILE. A name carries no extension exactly where it matters most: the git hooks are
  # shell, and both were invisible here while verify-narrative.sh already read them by shebang.
  case "$(basename "$1")" in *.*) echo ''; return;; esac
  [ -f "$1" ] && head -c 200 "$1" 2>/dev/null | head -1 | grep -q '^#!' && echo '#' || echo ''
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
  # No extension filter: it excluded every extensionless file BEFORE marker_for could ask the
  # file itself, which is precisely where the git hooks were hiding.
  done < <(git -C "$dir" ls-tree -r --name-only HEAD || true)

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

scan_tree . "$ref" "repo/"

# The workspace is a separate repository with no remote and no tag, and it is optional: a generated
# project can be created without it.
if [ -d ../workspace/.git ]; then
  ws_rev=$(git -C ../workspace rev-list -1 --before="$ref_at" HEAD 2>/dev/null || true)
  if [ -n "$ws_rev" ]; then
    scan_tree ../workspace "$ws_rev" "workspace/"
    scope="repo/ and workspace/"
  else
    echo "  ⚠ workspace: no commit predates $ref — nothing to compare against"
    grown=1
    scope="repo/ only (workspace unreadable)"
  fi
else
  # Said out loud: a bare tick here would read exactly like a clean neighbour.
  echo "  (no ../workspace/.git beside this repo — repo/ only)"
  scope="repo/ only"
fi

# ── Level and longest block, on the files this branch TOUCHES ──────────────────────────────
# Drift alone cannot see a file BORN verbose: it never grows, so it never speaks. Two absolute
# limits close that, and they apply to touched files only — the debt is paid where work happens,
# instead of turning the whole tree red on the day the rule lands.
COMMENT_LEVEL=${COMMENT_LEVEL_THRESHOLD:-25}
COMMENT_BLOCK=${COMMENT_BLOCK_THRESHOLD:-6}
level_checked=0

scan_touched() {         # <repository> <label>
  local dir="$1" label="$2" f marker list
  list=$(mktemp)
  { git -C "$dir" diff --name-only origin/main...HEAD 2>/dev/null
    git -C "$dir" diff --name-only HEAD 2>/dev/null
    git -C "$dir" diff --cached --name-only 2>/dev/null
  } | sort -u | while IFS= read -r f; do
        [ -n "$f" ] && [ -f "$dir/$f" ] || continue
        marker=$(marker_for "$f")
        [ -n "$marker" ] && printf '%s\t%s\n' "$marker" "$dir/$f"
      done > "$list"

  local n; n=$(grep -c . "$list" || true)
  level_checked=$(( level_checked + n ))
  if [ "$n" -gt 0 ]; then
    LABEL="$label" LEVEL="$COMMENT_LEVEL" BLOCK="$COMMENT_BLOCK" python3 - "$list" <<'PY' || return 1
import os, re, sys
label = os.environ["LABEL"]; LEVEL = int(os.environ["LEVEL"]); BLOCK = int(os.environ["BLOCK"])
bad = 0
for line in open(sys.argv[1], encoding="utf-8"):
    marker, path = line.rstrip("\n").split("\t", 1)
    try: lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    except OSError: continue
    lead = re.compile(r"^\s*" + re.escape(marker))
    com = code = longest = run = 0
    for k, l in enumerate(lines):
        if k == 0 and l.startswith("#!"):
            continue          # a shebang opens the file, it does not comment it
        if lead.match(l):
            com += 1; run += 1; longest = max(longest, run)
        else:
            run = 0
            if l.strip(): code += 1
    if com + code < 20:          # too small a base for a percentage to mean anything
        continue
    pct = com * 100 // (com + code)
    name = path.split("/")[-1]
    if pct > LEVEL:
        print(f"  ↑ {label}{name:<34} {pct}% comment (limit {LEVEL}%) — move the WHY to docs/, keep the constraint")
        bad += 1
    if longest > BLOCK:
        print(f"  ↑ {label}{name:<34} a {longest}-line comment block (limit {BLOCK}) — split it or move it out")
        bad += 1
sys.exit(1 if bad else 0)
PY
  fi
  return 0
}

scan_touched . "repo/" || grown=1
[ -d ../workspace/.git ] && { scan_touched ../workspace "workspace/" || grown=1; }

[ "$grown" = 0 ] && echo "✓ no comment outgrew its code since $ref, and none crossed ${COMMENT_LEVEL}% or a ${COMMENT_BLOCK}-line block — $scope; read:$read_out $level_checked touched file(s) for level and block"
if [ "$grown" != 0 ]; then
  cat >&2 <<'MSG'
  The whole file counts, not only the lines this branch added — a header written long ago is the
  usual reason a file crosses the level, and cutting today's lines instead leaves it uncorrected.
  A WHY that is worth keeping MOVES to docs/code/<name>.md; only a copy of the docs is deleted.
MSG
fi
exit "$grown"   # blocking: same reason
