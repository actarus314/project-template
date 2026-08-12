#!/usr/bin/env bash
# Fleet view: which generated projects run behind the template, from the harness's own project list.
# That list is a CACHE, never a registry — the table prints what it therefore cannot see.
# It parses NO stamp: the check does that, once, for everyone.
set -uo pipefail
# `|| exit 1`: SC2164 is a WARNING, so `-S warning` does not filter it and the gate would stop here.
cd "$(dirname "$0")" || exit 1

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

CHECK=./hooks/check-template-version.sh
[ -x "$CHECK" ] || { echo "· nothing read — $CHECK is missing or not executable"; exit 0; }
PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
[ -d "$PROJECTS_DIR" ] || { echo "· nothing read — no $PROJECTS_DIR on this machine"; exit 0; }

# A slug folded every "/" into a "-", and a folder name may itself hold a dash: the segments are
# walked shortest-first, testing existence at each step. Why a walk, and the cap: docs/code/fleet.md.
STEPS_MAX=2000   # a slug that resolves to nothing branches at every dash, and nothing else stops it
found=(); steps=0
_walk() {
  local base="$1" rest="$2" i seg tail
  steps=$((steps + 1)); [ "$steps" -le "$STEPS_MAX" ] || return 0
  if [ -z "$rest" ]; then [ -d "$base" ] && found+=("$base"); return 0; fi
  for ((i = 0; i <= ${#rest}; i++)); do
    if [ "$i" -eq "${#rest}" ]; then seg="$rest"; tail=""
    elif [ "${rest:i:1}" = "-" ]; then seg="${rest:0:i}"; tail="${rest:i+1}"
    else continue; fi
    [ -n "$seg" ] || continue
    [ -d "$base/$seg" ] || continue
    _walk "$base/$seg" "$tail"
  done
  return 0
}
# It fills `found` instead of printing: called in a command substitution it would fill a subshell's
# array, and the readings would be counted there and lost.
resolve() { found=(); steps=0; _walk "" "${1#-}"; [ "${#found[@]}" -gt 0 ]; }

lines=(); dead=(); slugs=0; scratch=0; ambiguous=0
for entry in "$PROJECTS_DIR"/*; do
  # Directories only: the glob already skips dot-files, this covers anything else dropped in.
  [ -d "$entry" ] || continue
  slug=$(basename "$entry"); slugs=$((slugs + 1))
  case "$slug" in
    -private-tmp-*|-tmp-*) scratch=$((scratch + 1)); continue ;;   # session scratchpads: prefix only
  esac
  if ! resolve "$slug"; then
    # A probe under $TMPDIR stays VISIBLE while it exists — that is what lets a constructed fleet
    # carry a late project. Gone, it is a cleaned-up temporary, never a project that moved.
    case "$slug" in
      -private-var-folders-*|-var-folders-*) scratch=$((scratch + 1)) ;;
      *) dead+=("$slug") ;;
    esac
    continue
  fi
  path="${found[0]}"
  # The generated layout is <project>/repo, so the folder's own name identifies no project.
  label=$(basename "$path"); [ "$label" != repo ] || label=$(basename "$(dirname "$path")")
  [ "${#found[@]}" -le 1 ] || { label="$label ⚠${#found[@]}"; ambiguous=$((ambiguous + 1)); }
  # Only the first line is kept, and relayed WHOLE: ⚠ ✓ · are multi-byte, so ${v:0:1} under LANG=C
  # hands back a truncated byte. The state stays readable because it opens the line.
  verdict=$(CLAUDE_PROJECT_DIR="$path" "$CHECK" 2>/dev/null | head -1)
  lines+=("$label|$verdict")
done

echo "project-template fleet — $slugs slug(s) read from $PROJECTS_DIR"
for e in "${lines[@]:-}"; do
  [ -n "$e" ] || continue
  printf '  %-22s %s\n' "${e%%|*}" "${e#*|}"
done
for e in "${dead[@]:-}"; do [ -n "$e" ] && printf '  ✗ %-22s (path no longer exists)\n' "$e"; done
printf '  read: %d slug(s), %d scratchpad(s) skipped or cleaned up, %d dead path(s). This list is the harness cache, not a registry: a project never opened with Claude Code is invisible here.\n' \
  "$slugs" "$scratch" "${#dead[@]}"
[ "$ambiguous" -eq 0 ] || printf '  ⚠N marks %d slug(s) that more than one reading resolves — the first one is what the row shows.\n' "$ambiguous"
exit 0
