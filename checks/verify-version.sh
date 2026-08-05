#!/usr/bin/env bash
# Coherence guard for the version.
#
# THE SINGLE SOURCE IS THE GIT TAG. It is authoritative because a ruleset makes it immutable,
# while a CHANGELOG heading or a plugin manifest can be rewritten in any pull request. Everything
# that can READ the tag does so, so the only drift possible is in the places that must, by their
# nature, carry a copy — and those are exactly what this script compares.
#
# Silent no-op until the first tag exists: there is nothing to compare before the first release.
#
# Usage:
#   ./verify-version.sh          # checks; exits 1 on any mismatch
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

# The version, so the sweep that compares them all can see this one too.
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

# 1. The newest VERSIONED CHANGELOG heading. `Unreleased` is skipped on purpose: it is the open
#    section, it never matches a tag, and demanding one would forbid work between two releases.
CHG=$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md | head -1)
if [ "$CHG" != "$VER" ]; then
  echo "✗ CHANGELOG: newest versioned heading is '${CHG:-none}', the newest tag is '$TAG'"
  fail=1
fi

# 2. Each shipped script must PRINT that version. This is what catches a constant hardcoded back
#    in: reading the tag cannot drift, a copied literal can.
# DERIVED, never written, and with NO extension filter: what git tracks as EXECUTABLE, whatever the
# language. Filtering on `*.sh` presumes the project is written in shell.
# The pattern matches a HANDLER, never a mention: check.sh names `--version` in a comment and answers
# it by running the whole lot, which a looser grep would then execute. Shell, Python, Node, Go and
# Java forms are recognised.
# 🔴 A COMPILED executable cannot be grepped at all — there is no source to match. Those are counted
# and NAMED as unexamined instead of being silently cleared, which is what the verdict used to do
# while its own comment claimed the opposite.
HANDLER='"\$\{1:-\}" = "--version"|^[[:space:]]*--version\)|add_argument\([^)]*--version|argv[^=]*==?=?[^=]*--version|includes\(.--version|Args\[[^]]*\][^=]*==[^=]*--version|equals\("--version"'
execs=$(git ls-files -s 2>/dev/null | awk '$1=="100755"{ $1=$2=$3=""; sub(/^ +/,""); print }')
scripts=$(printf '%s\n' "$execs" | grep -v '^$' | tr '\n' '\0' | xargs -0 grep -lE "$HANDLER" 2>/dev/null || true)
binaries=$(printf '%s\n' "$execs" | grep -v '^$' | while IFS= read -r f; do
             # `|| true` per iteration: the loop's status is the LAST test's, and under `set -e`
             # a final non-binary file killed the script with no output at all.
             { [ -f "$f" ] && ! grep -qI . "$f" 2>/dev/null && printf '%s ' "$f"; } || true; done)
[ -n "$scripts" ] || { echo "✗ no script handles --version — this check would pass by looking at nothing"; exit 1; }
# Asked in PARALLEL, answers read back in order. Files rather than a pipe: interleaved writes from
# concurrent jobs are what makes a parallel loop report the wrong script's version.
answers=$(mktemp -d)
trap 'rm -rf "$answers"' EXIT
for s in $scripts; do
  # STDIN closed: three of these are hooks that read their payload from it, and asking a
  # script its version must never leave one waiting on the terminal — inside check.sh's
  # parallel lot that is a hang with no output at all.
  # `./` is not decoration: git returns `configure-repo.sh`, and a bare relative name is
  # looked up in PATH, not in the tree — the whole lot then answered "command not found".
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

# 3. The plugin manifest, so it cannot become the copy nobody watches. Written before the file
#    existed and armed on its own the day it landed — the guard was in place before the drift
#    could happen, which is the only order that works for a silent one.
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
