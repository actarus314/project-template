#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   (what this does with a verdict; compared to the control table AND to its real exit code)
# Anti-drift safeguard between a docs/*.md (source of truth) and its hand-crafted docs/*.html.
#
# A docs/*.html carrying a `checksum-source-md: sha256:<hash>` header comment declares "I am the
# view of that .md at THIS hash". No such line -> silent, the case in every generated project.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root, regardless of the caller's cwd

# Each rule carries a TAG, and it is what reaches the journal: one control name for several
# rules left no way to know which of them ever bit. Absent CHECK_TAGS, the tag goes nowhere.
tag() { [ -n "${CHECK_TAGS:-}" ] && printf '%s\n' "$1" >>"$CHECK_TAGS"; return 0; }

# Usage:
#   checks/verify-checksums.sh             # checks; exits with an error (1) if a .md has drifted
#   checks/verify-checksums.sh --update    # recomputes and rewrites the checksum in each .html
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

# ADVISORY, never blocking: a checksum proves the .html was TOUCHED, never that it says the same
# thing. This lists the .md's technical tokens (backticked commands, files, flags) missing from the
# .html's rendered text — sentence comparison does not work here, these pages REINTERPRET their
# source. The measurements behind both thresholds: verify-checksums.md.
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
# The pairs are the observable: a project with none is the normal case (no generated project ships
# one). Counted so the verdict can say what was actually read, not just "found nothing".
pairs=0
for html in docs/*.html; do
  recorded=$(grep -o 'checksum-source-md: sha256:[0-9a-f]*' "$html" | awk -F: '{print $3}' || true)
  [ -n "$recorded" ] || continue   # no marker -> this .html is not concerned
  pairs=$((pairs + 1))

  md="${html%.html}.md"
  if [ ! -f "$md" ]; then
    tag html-names-missing-md
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
    tag html-behind-md
    echo "✗ $md changed since the last update of $html — carry the change over, then update the checksum with: checks/verify-checksums.sh --update" >&2
    fail=1
  fi
done

if [ "$pairs" = 0 ]; then
  echo "  (no docs/*.md + docs/*.html pair carrying a checksum marker here — nothing to check)"
fi

exit "$fail"
