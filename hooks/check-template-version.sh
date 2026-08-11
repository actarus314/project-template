#!/usr/bin/env bash
# Tells whoever opens a session that the template their project was born from has moved on.
# It never writes, never updates, never rewrites the stamp: knowing is not doing.
# NOT `set -e`: every failure path here still owes a printed line, and exiting would swallow it.
set -uo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "· NOT read: latest release — no curl on this machine"; exit 0; }

PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
AGENTS="$PROJECT/AGENTS.md"
[ -f "$AGENTS" ] || { echo "· no stamp — read: no AGENTS.md at $PROJECT (not generated from the template)"; exit 0; }

# Head block only: the stamp sits in the first lines, and a mention further down is prose about it.
head_block=$(head -n 12 "$AGENTS")
stamp=$(printf '%s\n' "$head_block" | grep -m1 'project-template')
[ -n "$stamp" ] || { echo "· no stamp — read: AGENTS.md head block, no project-template line"; exit 0; }

# Only markup and spaces may stand between the name and the version: the generator writes the
# version right after the name, and the OPTIONS in a second pair of backticks further along the
# same line. A class that merely stops at the first backtick reaches that second pair whenever the
# version is unreadable, and reports the options as the version.
marked=$(printf '%s' "$stamp" | sed -n 's/.*project-template[*[:space:]]*`v\{0,1\}\([^`]*\)`.*/\1/p')
origin=$(printf '%s\n' "$head_block" | sed -n 's|.*from \(https://github\.com/[^ ]*\).*|\1|p' | head -1)
[ -n "$marked" ] || { echo "· stamped, no version — read: $stamp"; echo "  no version between backticks after the name; nothing to compare"; exit 0; }

# A VERSION, never merely "something between backticks": sort -V orders numbers, so anything else
# has to be refused rather than ordered. This is a VALIDATION, not support for another format —
# the generator only ever writes a version number.
case "$marked" in
  *[!0-9.]*) echo "· stamped, but not with a version — read: \`$marked\` (not a version number, nothing sort -V can order)"; exit 0 ;;
esac
local_v="$marked"
[ -n "$origin" ] || { echo "· stamped v$local_v, NOT read: origin — no 'from <url>' in the head block"; exit 0; }

slug="${origin#https://github.com/}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/project-template"
CACHE="$CACHE_DIR/latest-${slug//\//-}"
MAX_AGE_MIN="${TEMPLATE_CACHE_MINUTES:-360}"   # 6 h — one call serves every project of the fleet

latest=""
# `find -mmin` is the portable age test here: `stat` takes different flags on macOS and on Linux.
if [ -f "$CACHE" ] && [ -n "$(find "$CACHE" -mmin "-$MAX_AGE_MIN" 2>/dev/null)" ]; then
  latest=$(cat "$CACHE")
else
  api="https://api.github.com/repos/$slug/releases/latest"
  # -w writes the status code AFTER the body, so one call yields both without a second request.
  resp=$(curl -sSL --max-time 3 -w '\n%{http_code}' "$api" 2>/dev/null)
  rc=$?
  code=$(printf '%s' "$resp" | tail -1)
  body=$(printf '%s' "$resp" | sed '$d')
  case "$rc:$code" in
    0:200) latest=$(printf '%s' "$body" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -1) ;;
    0:404) echo "⚠ NOT read: latest release — $api answered 404: no release, or the origin is wrong"; echo "  read: stamp v$local_v"; exit 0 ;;
    0:403) echo "⚠ NOT read: latest release — $api answered 403: the anonymous API allows 60 calls per hour per IP"; echo "  read: stamp v$local_v"; exit 0 ;;
    28:*)  echo "⚠ NOT read: latest release — $api did not answer within 3 s"; echo "  read: stamp v$local_v"; exit 0 ;;
    *)     echo "⚠ NOT read: latest release — curl exit $rc, HTTP ${code:-none}"; echo "  read: stamp v$local_v"; exit 0 ;;
  esac
  [ -n "$latest" ] || { echo "⚠ NOT read: latest release — $api answered 200 without a tag_name"; echo "  read: stamp v$local_v"; exit 0; }
  mkdir -p "$CACHE_DIR" && printf '%s' "$latest" > "$CACHE"
fi

newer_of() { printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1; }   # sort -V, never a string compare

# 🔴 The PROJECT's verdict goes FIRST, always: fleet.sh keeps only the first line, so anything
# printed above it would replace every project's own state with the same message.
if [ "$local_v" = "$latest" ] || [ "$(newer_of "$local_v" "$latest")" = "$local_v" ]; then
  echo "✓ up to date — read: stamp v$local_v, latest v$latest"
else
  echo "⚠ project-template v$local_v → v$latest — what changed: $origin/releases/tag/v$latest"
  echo "  read: stamp in AGENTS.md (v$local_v), latest release (v$latest)"
fi

# The plugin's OWN version, printed AFTER — the net for a user whose Claude Code does not
# auto-update third-party plugins. It is never the reference for the project: a late plugin
# would report "up to date".
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  plugin_v=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' \
             "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" | head -1)
  if [ -n "$plugin_v" ] && [ "$plugin_v" != "$latest" ] && [ "$(newer_of "$plugin_v" "$latest")" = "$latest" ]; then
    echo "⚠ this plugin is v$plugin_v, latest is v$latest — update: claude plugin update project-template"
  fi
fi
exit 0
