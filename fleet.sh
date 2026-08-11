#!/usr/bin/env bash
# Fleet view: which generated projects run behind the template. It reads the harness's own project
# list, which is a CACHE and never a registry — a project never opened with Claude Code is invisible
# here, and a moved one leaves a dead slug behind. Both limits are printed with the table.
# It parses NO stamp: the check does that, once, for everyone.
set -uo pipefail
# `|| exit 1`: shellcheck refuses a bare cd (SC2164), and SC2164 is a WARNING, so `-S warning` does
# not filter it — the gate command would stop before ever running check.sh.
cd "$(dirname "$0")" || exit 1

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

CHECK=./hooks/check-template-version.sh
[ -x "$CHECK" ] || { echo "· nothing read — $CHECK is missing or not executable"; exit 0; }
PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
[ -d "$PROJECTS_DIR" ] || { echo "· nothing read — no $PROJECTS_DIR on this machine"; exit 0; }

# A slug replaced every "/" with "-", and a folder name may itself contain a dash: walk the segments
# shortest-first and backtrack, testing existence at each step. A blind substitution loses 7 slugs
# out of 18 on this machine. Why a walk and not a table of exceptions: docs/code/fleet.md.
_walk() {
  local base="$1" rest="$2" i seg tail
  if [ -z "$rest" ]; then [ -d "$base" ] && { printf '%s\n' "$base"; return 0; }; return 1; fi
  for ((i = 0; i <= ${#rest}; i++)); do
    if [ "$i" -eq "${#rest}" ]; then seg="$rest"; tail=""
    elif [ "${rest:i:1}" = "-" ]; then seg="${rest:0:i}"; tail="${rest:i+1}"
    else continue; fi
    [ -n "$seg" ] || continue
    [ -d "$base/$seg" ] || continue
    _walk "$base/$seg" "$tail" && return 0
  done
  return 1
}
resolve() { _walk "" "${1#-}"; }

lines=(); dead=(); slugs=0; scratch=0
for entry in "$PROJECTS_DIR"/*; do
  # Directories only. A dot-file such as .DS_Store is never matched by this glob anyway — the test
  # is here for anything else the harness may drop in.
  [ -d "$entry" ] || continue
  slug=$(basename "$entry"); slugs=$((slugs + 1))
  case "$slug" in
    -private-tmp-*|-tmp-*) scratch=$((scratch + 1)); continue ;;   # session scratchpads: prefix only
  esac
  if ! path=$(resolve "$slug"); then dead+=("$slug"); continue; fi
  # ONE implementation, called once per project. Only the first line is kept: its first character
  # carries the state, which is the whole contract between the two.
  verdict=$(CLAUDE_PROJECT_DIR="$path" "$CHECK" 2>/dev/null | head -1)
  # The verdict is relayed WHOLE, never sliced: ⚠ ✓ · are multi-byte, and ${v:0:1} under LANG=C
  # returns a truncated byte. The state stays readable because it opens the line.
  lines+=("$(basename "$path")|$verdict")
done

echo "project-template fleet — $slugs slug(s) read from $PROJECTS_DIR"
for e in "${lines[@]:-}"; do
  [ -n "$e" ] || continue
  printf '  %-22s %s\n' "${e%%|*}" "${e#*|}"
done
for e in "${dead[@]:-}"; do [ -n "$e" ] && printf '  ✗ %-22s (path no longer exists)\n' "$e"; done
printf '  read: %d slug(s), %d scratchpad(s) skipped, %d dead path(s). This list is the harness cache, not a registry: a project never opened with Claude Code is invisible here.\n' \
  "$slugs" "$scratch" "${#dead[@]}"
exit 0
