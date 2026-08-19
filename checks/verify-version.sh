#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   (what this does with a verdict; compared to the control table AND to its real exit code)
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

# 1. The versioned CHANGELOG headings against the tags that exist; `Unreleased` is skipped.
#    RUNBOOK §3 seals BEFORE tagging, so the newest heading legitimately has no tag yet. AT MOST ONE
#    may be untagged, and it must be the newest: two means a sealed version never got its tag, and
#    no window explains that. Existence is the oracle — no version is ever compared to another.
headings=$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md)
CHG=$(printf '%s\n' "$headings" | head -1)
untagged=$(printf '%s\n' "$headings" | while read -r v; do
             [ -n "$v" ] && ! git rev-parse -q --verify "refs/tags/v$v" >/dev/null 2>&1 && echo "$v"; done || true)
n_untagged=$(printf '%s\n' "$untagged" | grep -c . || true)
pending=""
if [ "$n_untagged" -gt 1 ]; then
  echo "✗ CHANGELOG: $n_untagged headings carry no tag ($(printf '%s' "$untagged" | tr '\n' ' ')) — a sealed version never got tagged"
  fail=1
elif [ "$n_untagged" = 1 ] && [ "$untagged" != "$CHG" ]; then
  echo "✗ CHANGELOG: heading '$untagged' carries no tag, and it is not the newest one"
  fail=1
elif [ "$n_untagged" = 1 ]; then
  # Sealed and awaiting its tag: the heading BELOW it is what the newest tag must match, or the
  # gap is a tag with no heading rather than a heading with no tag.
  prev=$(printf '%s\n' "$headings" | sed -n 2p)
  if [ "$prev" != "$VER" ]; then
    echo "✗ CHANGELOG: '$CHG' awaits its tag, but the heading below is '${prev:-none}' and the newest tag is '$TAG'"
    fail=1
  else
    pending="$CHG"
  fi
elif [ "$CHG" != "$VER" ]; then
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
#    could happen, the day the file landed (verify-version.md). Compared to the CHANGELOG's newest
#    heading, never to the tag: the two are sealed in the same commit, one gesture ahead of the tag.
if [ -f .claude-plugin/plugin.json ]; then
  pv=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
  if [ "$pv" != "$CHG" ]; then
    echo "✗ .claude-plugin/plugin.json declares '$pv', the CHANGELOG's newest heading is '$CHG'"
    fail=1
  fi
fi

[ -n "$binaries" ] && echo "  (compiled executables, no source to read, not examined:$binaries)"
n_scripts=$(printf '%s\n' "$scripts" | grep -c . || true)
# AMBER, never green and never red: the sealing is merged and the tag is one command away, so the
# repository is half-published — a state the runbook creates on purpose, and which nothing else says.
if [ "$fail" = 0 ] && [ -n "$pending" ]; then
  echo "⚠ $pending is SEALED but NOT TAGGED — half-published: git tag v$pending && git push origin v$pending"
fi
[ "$fail" = 0 ] && echo "✓ version coherent everywhere: ${pending:+$pending sealed, }$TAG — read: CHANGELOG, $n_scripts executable(s)$([ -f .claude-plugin/plugin.json ] && echo ', the plugin manifest')"
exit "$fail"
