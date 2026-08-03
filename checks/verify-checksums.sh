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
#   docs/verify-checksums.sh             # checks; exits with an error (1) if a .md has drifted
#   docs/verify-checksums.sh --update    # recomputes and rewrites the checksum in each .html
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root, regardless of the caller's cwd

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

update=0
[ "${1:-}" = "--update" ] && update=1

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'   # macOS doesn't have sha256sum built in
  fi
}

# Technical-token coverage — the check the checksum CANNOT do.
#
# A checksum proves the .html was TOUCHED after the .md moved. Nothing more: an assembly has
# already passed it GREEN with 29% of the arriving facts missing — a whole block, sources
# included, rendered nowhere.
# (The full account — see workspace/archives/2026-08-decoupage-par-sujet/SYNTHESE.md.)
#
# So this lists the .md's technical tokens (whatever it puts between backticks: commands, files,
# flags — what cannot be reworded without becoming false) that appear nowhere in the .html's text.
# Comparing SENTENCES does not work: these pages REINTERPRET their source, and only 42% of the
# sentences survive, which drowns the signal.
#
# ADVISORY, never blocking — deliberately. A styled page renders a placeholder its own way, so a
# residue of two or three is normal, and a guard that cries on every run is a guard nobody reads.
# What it catches is the ORDER OF MAGNITUDE: 2 residual tokens against 23 when a block disappears.
coverage() {
  command -v python3 >/dev/null 2>&1 || { echo "  (python3 absent — coverage skipped)"; return 0; }
  python3 - "$1" "$2" <<'PY'
import re, sys, pathlib
md, html = sys.argv[1], sys.argv[2]
t = pathlib.Path(html).read_text()
t = re.sub(r"<(script|style)\b.*?</\1>", " ", t, flags=re.S | re.I)
t = re.sub(r"<!--.*?-->", " ", t, flags=re.S)
t = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", t))
NOISE = {"main", "develop", "yes", "read", "write", "true", "false"}
toks = set()
for raw in re.findall(r"`([^`\n]{2,60})`", pathlib.Path(md).read_text()):
    tok = re.sub(r"^[*_]{1,3}|[*_]{1,3}$", "", raw).strip()
    if "**" in tok:                       # capture ran across an unpaired backtick
        continue
    tok = re.split(r"[<{]", tok)[0].strip().rstrip("=-/ ")   # `gh pr view <n>` -> `gh pr view`
    if len(tok) >= 3 and tok.lower() not in NOISE:
        toks.add(tok)
absent = sorted(k for k in toks if k not in t)
print(f"  coverage: {len(toks)} technical tokens, {len(absent)} absent from the page")
for a in absent[:12]:
    print(f"    absent  {a}")
if len(absent) > 12:
    print(f"    … and {len(absent)-12} more")
PY
}

fail=0
shopt -s nullglob
for html in docs/*.html; do
  recorded=$(grep -o 'checksum-source-md: sha256:[0-9a-f]*' "$html" | awk -F: '{print $3}' || true)
  [ -n "$recorded" ] || continue   # no marker -> this .html is not concerned

  md="${html%.html}.md"
  if [ ! -f "$md" ]; then
    echo "✗ $html references $md, not found" >&2
    fail=1
    continue
  fi

  current=$(sha256 "$md")

  if [ "$update" = 1 ]; then
    # BEFORE sealing: sealing is the moment the author states "the change has been carried over",
    # so it is the moment that claim is worth measuring.
    coverage "$md" "$html"
    sed -i.bak "s/checksum-source-md: sha256:[0-9a-f]*/checksum-source-md: sha256:$current/" "$html"
    rm -f "$html.bak"
    echo "✓ $html: checksum updated ($current)"
    continue
  fi

  if [ "$current" = "$recorded" ]; then
    echo "✓ $html up to date with $md"
    coverage "$md" "$html"
  else
    echo "✗ $md changed since the last update of $html — carry the change over, then update the checksum with: docs/verify-checksums.sh --update" >&2
    fail=1
  fi
done

exit "$fail"
