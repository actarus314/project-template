#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# Coherence guard for the version. THE SINGLE SOURCE IS THE GIT TAG — a ruleset makes it immutable,
# while a CHANGELOG heading or a plugin manifest can be rewritten in any PR (why: verify-version.md).
# Silent no-op until the first tag exists: nothing to compare before the first release.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ -z "$TAG" ]; then
  echo "no tag yet — nothing to compare (the guard arms itself at the first release)"
  exit 0
fi
VER="${TAG#v}"
fail=0

# 1. Newest VERSIONED CHANGELOG heading; `Unreleased` is skipped since it never matches a tag.
CHG=$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md | head -1)
if [ "$CHG" != "$VER" ]; then
  echo "✗ CHANGELOG: newest versioned heading is '${CHG:-none}', the newest tag is '$TAG'"
  fail=1
fi

# 2. Each shipped script must PRINT that version — catches a constant hardcoded back in, since
#    reading the tag cannot drift but a copied literal can. DERIVED from what git tracks as
#    EXECUTABLE (no extension filter — this template is not shell-only), matched by a HANDLER
#    pattern, never by a mention (why, and the compiled-binary caveat: verify-version.md).
HANDLER='"\$\{1:-\}" = "--version"|^[[:space:]]*--version\)|add_argument\([^)]*--version|argv[^=]*==?=?[^=]*--version|includes\(.--version|Args\[[^]]*\][^=]*==[^=]*--version|equals\("--version"'
execs=$(git ls-files -s 2>/dev/null | awk '$1=="100755"{ $1=$2=$3=""; sub(/^ +/,""); print }')
scripts=$(printf '%s\n' "$execs" | grep -v '^$' | tr '\n' '\0' | xargs -0 grep -lE "$HANDLER" 2>/dev/null || true)
binaries=$(printf '%s\n' "$execs" | grep -v '^$' | while IFS= read -r f; do
             # under `set -e`, a non-binary file at the loop's end must not kill it with no output:
             { [ -f "$f" ] && ! grep -qI . "$f" 2>/dev/null && printf '%s ' "$f"; } || true; done)
[ -n "$scripts" ] || { echo "✗ no script handles --version — this check would pass by looking at nothing"; exit 1; }
# Asked in PARALLEL, answers read back in order — files, not a pipe, so concurrent writes can't interleave.
answers=$(mktemp -d)
trap 'rm -rf "$answers"' EXIT
for s in $scripts; do
  # STDIN closed (three of these are hooks reading their payload from it) and `./`-prefixed (a
  # bare name is looked up in PATH, not in the tree) — both pitfalls, detailed in verify-version.md.
  ( "./$s" --version </dev/null 2>/dev/null | tail -1 | awk '{print $NF}' \
      > "$answers/$(printf '%s' "$s" | tr '/' '_')" ) &
done
wait
for s in $scripts; do
  # A job that died wrote nothing, and an empty answer must read as a MISMATCH, never as a pass.
  got=$(cat "$answers/$(printf '%s' "$s" | tr '/' '_')" 2>/dev/null || true)
  if [ "$got" != "$TAG" ]; then
    echo "✗ $s --version prints '${got:-nothing}', expected '$TAG'"
    fail=1
  fi
done

# 3. The plugin manifest, so it cannot become the copy nobody watches — armed before the drift
#    could happen, the day the file landed (verify-version.md).
if [ -f .claude-plugin/plugin.json ]; then
  pv=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
  if [ "$pv" != "$VER" ]; then
    echo "✗ .claude-plugin/plugin.json declares '$pv', the newest tag is '$TAG'"
    fail=1
  fi
fi

[ -n "$binaries" ] && echo "  (compiled executables, no source to read, not examined:$binaries)"
n_scripts=$(printf '%s\n' "$scripts" | grep -c . || true)
[ "$fail" = 0 ] && echo "✓ version coherent everywhere: $TAG — read: CHANGELOG, $n_scripts executable(s)$([ -f .claude-plugin/plugin.json ] && echo ', the plugin manifest')"
exit "$fail"
