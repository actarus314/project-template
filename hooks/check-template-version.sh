#!/usr/bin/env bash
# Tells whoever opens a session that the template their project was born from has moved on.
# It never writes, never updates, never rewrites the stamp: knowing is not doing.
# NOT `set -e`: every failure path here still owes a printed line, and exiting would swallow it.
set -uo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
AGENTS="$PROJECT/AGENTS.md"
[ -f "$AGENTS" ] || { echo "· no stamp — read: no AGENTS.md at $PROJECT (not generated from the template)"; exit 0; }

# Head block only: the stamp sits in the first lines, and a mention further down is prose about it.
head_block=$(head -n 12 "$AGENTS")
stamp=$(printf '%s\n' "$head_block" | grep -m1 'project-template')
[ -n "$stamp" ] || { echo "· no stamp — read: AGENTS.md head block, no project-template line"; exit 0; }

# The stamp is a sentence of prose: relayed whole it floods the fleet table, one row per project.
short() { if [ "${#1}" -gt 60 ]; then printf '%.60s…' "$1"; else printf '%s' "$1"; fi; }

# Only markup and spaces may stand between the name and the version: a class merely stopping at the
# first backtick reaches the OPTIONS, further along the same line, and reports them as the version.
marked=$(printf '%s' "$stamp" | sed -n 's/.*project-template[*[:space:]]*`v\{0,1\}\([^`]*\)`.*/\1/p')
origin=$(printf '%s\n' "$head_block" | sed -n 's|.*from \(https://github\.com/[^ ]*\).*|\1|p' | head -1)
[ -n "$marked" ] || { echo "· stamped, no version — read: $(short "$stamp")"; echo "  no version between backticks after the name; nothing to compare"; exit 0; }

# A VERSION, never merely "something between backticks": sort -V orders numbers, and returns an
# answer for anything else — so what it cannot order has to be refused rather than ordered.
case "$marked" in
  *[!0-9.]*) echo "· stamped, but not with a version — read: \`$marked\` (not a version number, nothing sort -V can order)"; exit 0 ;;
esac
local_v="$marked"
[ -n "$origin" ] || { echo "· stamped v$local_v, NOT read: origin — no 'from <url>' in the head block"; exit 0; }

slug="${origin#https://github.com/}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/project-template"
# "%" cannot appear in a GitHub owner or repo name; a "-" can, and made two origins share ONE file.
CACHE="$CACHE_DIR/latest-${slug//\//%}"
UNREACHABLE="$CACHE.unreachable"
MAX_AGE_MIN="${TEMPLATE_CACHE_MINUTES:-360}"   # 6 h — one call serves every project of the fleet
RETRY_MIN="${TEMPLATE_RETRY_MINUTES:-15}"      # a dead network is remembered, or every session pays the timeout again

# `find -mmin` is the portable age test here: `stat` takes different flags on macOS and on Linux.
fresh() { [ -f "$1" ] && [ -n "$(find "$1" -mmin "-$2" 2>/dev/null)" ]; }
remember_unreachable() { mkdir -p "$CACHE_DIR" 2>/dev/null && : > "$UNREACHABLE" 2>/dev/null; return 0; }
# Written aside then moved: half a version number still reads as a version number.
write_cache() {
  local tmp="$CACHE.$$"
  mkdir -p "$CACHE_DIR" 2>/dev/null || return 1
  { printf '%s' "$1" > "$tmp"; } 2>/dev/null && mv -f "$tmp" "$CACHE" 2>/dev/null && return 0
  rm -f "$tmp" 2>/dev/null
  return 1
}

trailer=""   # printed AFTER the verdict, never above it
latest=""
if fresh "$CACHE" "$MAX_AGE_MIN"; then
  latest=$(cat "$CACHE")
elif fresh "$UNREACHABLE" "$RETRY_MIN"; then
  echo "⚠ NOT read: latest release — unreachable less than $RETRY_MIN min ago, not called again"
  echo "  read: stamp v$local_v"
  exit 0
else
  # Tested HERE, not at the top: a project with no stamp owes a message about its stamp.
  command -v curl >/dev/null 2>&1 || { echo "· NOT read: latest release — no curl on this machine"; echo "  read: stamp v$local_v"; exit 0; }
  api="https://api.github.com/repos/$slug/releases/latest"
  # -w writes the status code AFTER the body, so one call yields both without a second request.
  resp=$(curl -sSL --max-time 3 -w '\n%{http_code}' "$api" 2>/dev/null)
  rc=$?
  code=$(printf '%s' "$resp" | tail -1)
  body=$(printf '%s' "$resp" | sed '$d')
  case "$rc:$code" in
    0:200) latest=$(printf '%s' "$body" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -1) ;;
    0:404) echo "⚠ NOT read: latest release — $api answered 404: no release, or the origin is wrong"; echo "  read: stamp v$local_v"; exit 0 ;;
    0:403) remember_unreachable; echo "⚠ NOT read: latest release — $api answered 403: the anonymous API allows 60 calls per hour per IP"; echo "  read: stamp v$local_v"; exit 0 ;;
    28:*)  remember_unreachable; echo "⚠ NOT read: latest release — $api did not answer within 3 s"; echo "  read: stamp v$local_v"; exit 0 ;;
    *)     remember_unreachable; echo "⚠ NOT read: latest release — curl exit $rc, HTTP ${code:-none}"; echo "  read: stamp v$local_v"; exit 0 ;;
  esac
  [ -n "$latest" ] || { echo "⚠ NOT read: latest release — $api answered 200 without a tag_name"; echo "  read: stamp v$local_v"; exit 0; }
  write_cache "$latest" || trailer="  · NOT written: the cache under $CACHE_DIR — the network is called again next session"
fi

# `sort -V` ranks 1.2 BELOW 1.2.0, so a two-part stamp would read as late against a three-part
# release. Both sides are padded to three parts before being ordered — never a string compare.
pad3() { local a b c IFS=.; read -r a b c <<<"$1"; printf '%s.%s.%s' "${a:-0}" "${b:-0}" "${c:-0}"; }
newer_of() { printf '%s\n%s\n' "$(pad3 "$1")" "$(pad3 "$2")" | sort -V | tail -1; }

# 🔴 The PROJECT's verdict goes FIRST, always: fleet.sh keeps only the first line, so anything
# printed above it would replace every project's own state with the same message.
if [ "$(pad3 "$local_v")" = "$(pad3 "$latest")" ] || [ "$(newer_of "$local_v" "$latest")" = "$(pad3 "$local_v")" ]; then
  echo "✓ up to date — read: stamp v$local_v, latest v$latest"
else
  echo "⚠ project-template v$local_v → v$latest — what changed: $origin/releases/tag/v$latest"
  echo "  read: stamp in AGENTS.md (v$local_v), latest release (v$latest)"
fi
[ -z "$trailer" ] || echo "$trailer"

# The plugin's OWN version, printed AFTER — it is never the reference for the project: a late
# plugin would report "up to date". The key is read at the start of a line, so a "version" sitting
# inside another value is not taken for the manifest's own. What this does NOT cover: the .md note.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  plugin_v=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' \
             "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" | head -1)
  if [ -n "$plugin_v" ] && [ "$(pad3 "$plugin_v")" != "$(pad3 "$latest")" ] && [ "$(newer_of "$plugin_v" "$latest")" = "$(pad3 "$latest")" ]; then
    echo "⚠ this plugin is v$plugin_v, latest is v$latest — update: claude plugin update project-template"
  fi
fi
exit 0
