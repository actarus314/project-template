#!/usr/bin/env bash
# Relative markdown links that resolve nowhere — in BOTH repos.
#
# A dead link is invisible: nothing renders an error, the reader simply lands nowhere and stops
# following pointers. And this repo runs on pointers — a fact lives in ONE place and everywhere
# else there is a link, so a broken one silently turns "one source" back into "no source".
#
# It bites hardest right after a move: files were archived, sections extracted, docs renamed, and
# every pointer aimed at them had to follow. Doing that by hand is what this replaces.
#
# ⚠ NEVER read inside backticks. `docs/X.md` and `(…/releases/tag/vX.Y.Z)` are FORMAT EXAMPLES,
#   not links — reading them produced the only false positive of the manual pass.
#
# Scope: relative links only. An http(s) target is someone else's uptime, and an anchor (#…) would
# need the heading table — worth having one day, not worth a false positive today.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (python3 absent — links not checked)"; exit 0; }

python3 - . ../workspace <<'PY'
import re, sys, pathlib

LINK = re.compile(r"\[[^\]]*\]\((?!https?:|mailto:|#)([^)\s]+)\)")
CODE = re.compile(r"`[^`\n]*`")
SKIP = {".git", "node_modules", ".ci-tools", "venv"}
bad = []
# What was actually READ, and it gets published. A root that is not there reads exactly like a root
# with nothing wrong in it, so a count is the only thing that tells the two apart.
read, absent, files = [], [], 0

for root in (pathlib.Path(a) for a in sys.argv[1:]):
    if not root.is_dir():
        absent.append(str(root))
        continue
    read.append(str(root))
    for md in sorted(root.rglob("*.md")):
        if any(s in md.parts for s in SKIP):
            continue
        files += 1
        # blank out inline code FIRST: a backticked path is an example, not a link
        text = CODE.sub(lambda m: " " * len(m.group(0)), md.read_text())
        for target in sorted(set(LINK.findall(text))):
            tgt = target.split("#", 1)[0]
            # a placeholder is a naming EXAMPLE, never a link: 0000-<slug>.md, 000Y-….md
            if not tgt or any(c in tgt for c in "…<>*"):
                continue
            if not (md.parent / tgt).exists():
                bad.append(f"{md}: {target}")

for b in bad:
    print(f"✗ dead link — {b}", file=sys.stderr)
scope = f"{files} file(s) in {', '.join(read) or 'nothing'}"
if absent:
    scope += f" — NOT read: {', '.join(absent)} (absent)"
print(f"✓ every relative link resolves — {scope}" if not bad
      else f"✗ {len(bad)} dead link(s) — {scope}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
