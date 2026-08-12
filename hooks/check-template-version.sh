#!/usr/bin/env bash
# Tells whoever opens a session that the template their project was born from has moved on, and
# that the plugin carrying this check is itself late. It never writes, never updates, never
# rewrites the stamp: knowing is not doing.
# NOT `set -e`: every failure path here still owes a printed line, and exiting would swallow it.
set -uo pipefail

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/project-template"
MAX_AGE_MIN="${TEMPLATE_CACHE_MINUTES:-360}"   # 6 h — one call serves every project of the fleet
RETRY_MIN="${TEMPLATE_RETRY_MINUTES:-15}"      # a dead network is remembered, or every session pays the timeout again
LATEST=""; FAIL=""; trailer=""

# `find -mmin` is the portable age test here: `stat` takes different flags on macOS and on Linux.
fresh() { [ -f "$1" ] && [ -n "$(find "$1" -mmin "-$2" 2>/dev/null)" ]; }
remember() { mkdir -p "$CACHE_DIR" 2>/dev/null && : > "$1" 2>/dev/null; return 0; }
# Written aside then moved: half a version number still reads as a version number.
write_cache() {
  local tmp="$1.$$"
  mkdir -p "$CACHE_DIR" 2>/dev/null || return 1
  { printf '%s' "$2" > "$tmp"; } 2>/dev/null && mv -f "$tmp" "$1" 2>/dev/null && return 0
  rm -f "$tmp" 2>/dev/null
  return 1
}

# ONE reader for the two questions asked here — the project's origin, and the plugin's own
# repository. It fills LATEST or FAIL: called in a command substitution, both would die with the
# subshell. "%" cannot appear in a GitHub owner or repo name; a "-" can, and made two different
# origins share ONE cache file, each answering for the other.
fetch() {
  local slug="$1" cache unreachable api resp rc code body cached
  cache="$CACHE_DIR/latest-${slug//\//%}"; unreachable="$cache.unreachable"
  LATEST=""; FAIL=""; cached=1
  if fresh "$cache" "$MAX_AGE_MIN"; then
    LATEST=$(cat "$cache")
  else
    cached=0
    fresh "$unreachable" "$RETRY_MIN" && { FAIL="unreachable less than $RETRY_MIN min ago, not called again"; return 1; }
    command -v curl >/dev/null 2>&1 || { FAIL="no curl on this machine"; return 1; }
    api="https://api.github.com/repos/$slug/releases/latest"
    # -w writes the status code AFTER the body, so one call yields both without a second request.
    resp=$(curl -sSL --max-time 3 -w '\n%{http_code}' "$api" 2>/dev/null); rc=$?
    code=$(printf '%s' "$resp" | tail -1); body=$(printf '%s' "$resp" | sed '$d')
    case "$rc:$code" in
      0:200) LATEST=$(printf '%s' "$body" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -1) ;;
      0:404) FAIL="$api answered 404: no release, or the address is wrong"; return 1 ;;
      0:403) remember "$unreachable"; FAIL="$api answered 403: the anonymous API allows 60 calls per hour per IP"; return 1 ;;
      28:*)  remember "$unreachable"; FAIL="$api did not answer within 3 s"; return 1 ;;
      *)     remember "$unreachable"; FAIL="curl exit $rc, HTTP ${code:-none}"; return 1 ;;
    esac
    [ -n "$LATEST" ] || { FAIL="$api answered 200 without a tag_name"; return 1; }
  fi
  # ONE validation, past BOTH doors: placed on the network path alone, it left a cached value
  # unchecked — and a cached value is what nearly every session reads.
  case "$LATEST" in *[!0-9.]*) FAIL="\`$LATEST\` is not a version number, and sort -V cannot order it"; LATEST=""; return 1 ;; esac
  [ "$cached" = 1 ] || write_cache "$cache" "$LATEST" || trailer="  · NOT written: the cache under $CACHE_DIR — the network is called again next session"
  return 0
}

# `sort -V` ranks 1.2 BELOW 1.2.0, so a two-part version would read as late against a three-part
# one. Both sides are padded to three parts before being ordered — never a string compare.
pad3() { local a b c IFS=.; read -r a b c <<<"$1"; printf '%s.%s.%s' "${a:-0}" "${b:-0}" "${c:-0}"; }
newer_of() { printf '%s\n%s\n' "$(pad3 "$1")" "$(pad3 "$2")" | sort -V | tail -1; }
key() { sed -n "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -1; }

# The plugin's own state, on EVERY exit path and always LAST — Claude Code does not auto-update a
# third-party marketplace, so this line is the only thing that will say so. It reads its OWN
# repository from the manifest: the open folder is usually not generated from this template, and
# subordinating this to the project's origin left the net silent in every one of those folders.
plugin_line() {
  local m="${CLAUDE_PLUGIN_ROOT:-}/.claude-plugin/plugin.json" pv pslug
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$m" ] || return 0
  pv=$(key "$m" version); pv="${pv#v}"
  case "$pv" in ''|*[!0-9.]*) echo "· NOT read: this plugin's version — its manifest holds no version number"; return 0 ;; esac
  pslug=$(key "$m" repository); pslug="${pslug#https://github.com/}"; pslug="${pslug%.git}"
  [ -n "$pslug" ] || { echo "· NOT read: this plugin's releases — its manifest names no repository"; return 0; }
  fetch "$pslug" || { echo "⚠ NOT read: this plugin's latest release — $FAIL"; return 0; }
  [ "$(pad3 "$pv")" != "$(pad3 "$LATEST")" ] && [ "$(newer_of "$pv" "$LATEST")" = "$(pad3 "$LATEST")" ] || return 0
  echo "⚠ this plugin is v$pv, latest is v$LATEST — update: claude plugin update project-template"
}
trap plugin_line EXIT

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

case "$marked" in
  *[!0-9.]*) echo "· stamped, but not with a version — read: \`$marked\` (not a version number, nothing sort -V can order)"; exit 0 ;;
esac
local_v="$marked"
[ -n "$origin" ] || { echo "· stamped v$local_v, NOT read: origin — no 'from <url>' in the head block"; exit 0; }

slug="${origin#https://github.com/}"
fetch "$slug" || { echo "⚠ NOT read: latest release — $FAIL"; echo "  read: stamp v$local_v"; exit 0; }
latest="$LATEST"

# 🔴 The PROJECT's verdict goes FIRST, always: fleet.sh keeps only the first line, so anything
# printed above it would replace every project's own state with the same message.
if [ "$(pad3 "$local_v")" = "$(pad3 "$latest")" ] || [ "$(newer_of "$local_v" "$latest")" = "$(pad3 "$local_v")" ]; then
  echo "✓ up to date — read: stamp v$local_v, latest v$latest"
else
  echo "⚠ project-template v$local_v → v$latest — what changed: $origin/releases/tag/v$latest"
  echo "  read: stamp in AGENTS.md (v$local_v), latest release (v$latest)"
fi
[ -z "$trailer" ] || echo "$trailer"
exit 0
