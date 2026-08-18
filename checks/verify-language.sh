#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# French left in published content — the standard keeps repo/ in English.
# THREE signals, all binary: the ACCENT, the DECIMAL COMMA, and a PERCENT glued to its value.
# Unaccented French PROSE is not covered, and the verdict says so.
# 🔴 Four deliberate exemption classes, and why each one exists: docs/code/verify-language.md.

set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped, and this check read NOTHING)"; exit 0; }

python3 - <<'PY'
import re, subprocess, sys, pathlib

ACCENT = re.compile(r"[àâäåçéèêëîïôöùûüÿñæœÀÂÄÅÇÉÈÊËÎÏÔÖÙÛÜŸÑÆŒ]")
FR_HALF = re.compile(r"^#{1,2} .*\(fran[çc]ais\)\s*$")
# A heredoc opening whose redirect names workspace/ — the French side, by construction.
HEREDOC = re.compile(r"<<-?\s*'?([A-Za-z_][A-Za-z0-9_]*)'?")
MARKER = "fr-pattern"   # verify-tone.sh's marker: one convention, not two
QUOTED = re.compile(r'"[^"]*"|`[^`]*`|\'[^\']*\'')
# A decimal comma is French, carries no accent, and nothing else here reads it. The lookarounds
# spare what is NOT a number: a regex quantifier {1,3}, a CSS rgba(16,21,28,.06), an argument
# list substr(s,1,60). A comma between digits is never a thousands separator either: the SI
# proscribes it outright, so `6,766` is as wrong as `0,07` and both are refused.
DECIMAL = re.compile(r"(?<![\d.{,\-:($])\b\d{1,3},\d+\b(?![}\d,])")
# A percent sign glued to its value: NIST §15 puts a space between a value and its unit symbol.
# Anchored on what precedes the NUMBER, to leave CSS (width:100%), a transform (translateX(-50%))
# and a git format (%09%(refname)) alone.
PERCENT = re.compile(r"(?<![:%\-\d.])\d+(?:\.\d+)?%")
# The templates that stay French by rule (standard §1) — their decimals are French too.
FR_FILE = re.compile(r"^templates/(workspace/|repo/\.envrc$)")

out = subprocess.run(["git", "ls-files"], capture_output=True, text=True)
if out.returncode != 0:
    print("  (not a git repository — this check read NOTHING)")
    sys.exit(0)

files = [f for f in out.stdout.splitlines() if f]
read = skipped = 0
hits = []
dec_hits = []
pct_hits = []

for f in files:
    p = pathlib.Path(f)
    try:
        text = p.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        continue                      # binary or unreadable: no prose to judge
    read += 1
    french_half = False
    heredoc_end = None                # set while inside a heredoc that writes into workspace/
    for i, line in enumerate(text.splitlines(), 1):
        if heredoc_end is not None:
            if line.strip() == heredoc_end:
                heredoc_end = None
            else:
                skipped += 1
                continue
        if FR_HALF.match(line):
            french_half = True
        if french_half:
            skipped += 1
            continue
        if "workspace/" in line:
            m = HEREDOC.search(line)
            if m:
                heredoc_end = m.group(1)
                continue
        if MARKER in line:
            skipped += 1
            continue
        # Quoted spans are verbatim material, judged by nobody here.
        bare = QUOTED.sub(" ", line)
        if ACCENT.search(bare):
            hits.append((f, i, line.strip()[:100]))
        if not FR_FILE.match(f):
            for m in DECIMAL.finditer(bare):
                dec_hits.append((f, i, m.group(0), line.strip()[:100]))
            for m in PERCENT.finditer(bare):
                pct_hits.append((f, i, m.group(0), line.strip()[:100]))

if hits:
    print(f"✗ accented French in versioned content — {len(hits)} line(s):")
    for f, i, line in hits[:20]:
        print(f"    {f}:{i}  {line}")
    if len(hits) > 20:
        print(f"    … and {len(hits) - 20} more")
    print("  Translate it, or mark the line `fr-pattern` if it must carry French to do its job.")
    sys.exit(1)

if dec_hits:
    print(f"✗ French decimal comma in versioned content — {len(dec_hits)} occurrence(s):")
    for f, i, num, line in dec_hits[:20]:
        print(f"    {f}:{i}  {num}  in  {line}")
    if len(dec_hits) > 20:
        print(f"    … and {len(dec_hits) - 20} more")
    print("  English writes the decimal point: 0.07 s, not 0,07 s.")
    sys.exit(1)

if pct_hits:
    print(f"✗ percent sign glued to its value — {len(pct_hits)} occurrence(s):")
    for f, i, num, line in pct_hits[:20]:
        print(f"    {f}:{i}  {num}  in  {line}")
    if len(pct_hits) > 20:
        print(f"    … and {len(pct_hits) - 20} more")
    print("  A value and its unit symbol are separated by a space: 25 %, not 25%.")
    sys.exit(1)

print(f"✓ no accented French, no decimal comma, no glued percent in versioned content — read: "
      f"{read} text file(s) in repo/, {skipped} deliberate line(s) skipped (bilingual halves, "
      f"workspace heredocs, fr-pattern markers). Unaccented French PROSE is NOT covered.")
PY
