#!/usr/bin/env bash
# Anti-drift safeguard between docs/X.md (source of truth) and docs/X.html (hand-crafted layout).
#
# Every docs/X.html carrying a `checksum-source-md: sha256:<hash>` line in its header
# comment declares "I am the view of docs/X.md at THIS hash". This script recomputes the sha256
# of the .md and compares it to the one recorded in the .html. No `checksum-source-md:` line in
# an .html -> this file is not concerned, silent (the case for every generated project, which has
# none of these files).
#
# Usage:
#   docs/verifier-checksums.sh          # checks; exits with an error (1) if a .md has drifted
#   docs/verifier-checksums.sh --maj    # recomputes and rewrites the checksum in each .html
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root, regardless of the caller's cwd

maj=0
[ "${1:-}" = "--maj" ] && maj=1

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'   # macOS doesn't have sha256sum built in
  fi
}

fail=0
shopt -s nullglob
for html in docs/*.html; do
  stocke=$(grep -o 'checksum-source-md: sha256:[0-9a-f]*' "$html" | awk -F: '{print $3}' || true)
  [ -n "$stocke" ] || continue   # no marker -> this .html is not concerned

  md="${html%.html}.md"
  if [ ! -f "$md" ]; then
    echo "✗ $html references $md, not found" >&2
    fail=1
    continue
  fi

  actuel=$(sha256 "$md")

  if [ "$maj" = 1 ]; then
    sed -i.bak "s/checksum-source-md: sha256:[0-9a-f]*/checksum-source-md: sha256:$actuel/" "$html"
    rm -f "$html.bak"
    echo "✓ $html: checksum updated ($actuel)"
    continue
  fi

  if [ "$actuel" = "$stocke" ]; then
    echo "✓ $html up to date with $md"
  else
    echo "✗ $md changed since the last update of $html — carry the change over, then update the checksum with: docs/verifier-checksums.sh --maj" >&2
    fail=1
  fi
done

exit "$fail"
