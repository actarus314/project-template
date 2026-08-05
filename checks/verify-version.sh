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
# The list is DERIVED, never written: every executable that HANDLES `--version` is checked, so one
# added is covered the day it lands. A hand-kept list held 3 of the 16 that handle it.
#
# 🔴 NO EXTENSION FILTER, and that is the point. It used to look at `./*.sh checks/*.sh`, which
# presumes the project is written in shell — the same assumption that once made a travelling check
# read ZERO files in every Python, TypeScript and Go project. What is looked at now is what git
# tracks AS EXECUTABLE, whatever the language: a Python entry point, a Node CLI, a Go wrapper.
#
# The pattern still matches a HANDLER, never a mention — check.sh names `--version` in a comment
# and answers it by running the whole lot, which a looser grep would then execute. The forms below
# are the handler in shell, in Python and in Node; any other language is not recognised, and the
# verdict says so rather than implying the file was cleared.
HANDLER='"\$\{1:-\}" = "--version"|^[[:space:]]*--version\)|add_argument\([^)]*--version|argv[^=]*==?=?[^=]*--version|includes\(.--version'
execs=$(git ls-files -s 2>/dev/null | awk '$1=="100755"{ $1=$2=$3=""; sub(/^ +/,""); print }')
scripts=$(printf '%s\n' "$execs" | grep -v '^$' | tr '\n' '\0' | xargs -0 grep -lE "$HANDLER" 2>/dev/null || true)
[ -n "$scripts" ] || { echo "✗ no script handles --version — this check would pass by looking at nothing"; exit 1; }
for s in $scripts; do
  # STDIN closed: three of these are hooks that read their payload from it, and asking a
  # script its version must never leave one waiting on the terminal — inside check.sh's
  # parallel lot that is a hang with no output at all.
  # `./` is not decoration: git returns `configure-repo.sh`, and a bare relative name is
  # looked up in PATH, not in the tree — the whole lot then answered "command not found".
  got=$("./$s" --version </dev/null 2>/dev/null | tail -1 | awk '{print $NF}')
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

[ "$fail" = 0 ] && echo "✓ version coherent everywhere: $TAG"
exit "$fail"
