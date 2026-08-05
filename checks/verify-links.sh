#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
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
# Scope: relative links, and their ANCHORS. An http(s) target is someone else's uptime and stays
# out; an anchor is checked against the headings of the file it aims at, which is what makes a
# table of contents safe to write — a section renamed otherwise leaves every pointer dangling.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (python3 absent — links not checked)"; exit 0; }

python3 - . ../workspace <<'PY'
import re, sys, pathlib

LINK = re.compile(r"\[[^\]]*\]\((?!https?:|mailto:)([^)\s]+)\)")
CODE = re.compile(r"`[^`\n]*`")
FENCE = re.compile(r"```.*?```", re.S)

# The heading slug: lowercased, inline markup dropped, anything that is not a word character or a
# dash removed, spaces turned into dashes.
# ⚠ Close to GitHub's, not identical: `\w` keeps characters GitHub strips (a circled digit, say).
#   What matters here is that ONE convention is applied to both sides — the anchor and the heading
#   it aims at — so a link and its target agree or they do not. For a page GitHub actually renders,
#   its own rendering stays the authority.
def slug(s):
    s = re.sub(r"`|\*\*|\*|_", "", s)
    s = re.sub(r"[^\w\s-]", "", s, flags=re.U)
    return re.sub(r"\s+", "-", s.strip()).lower()

_heads = {}
def headings(path):
    key = str(path)
    if key not in _heads:
        try:
            text = path.read_text()
        except OSError:
            _heads[key] = set(); return _heads[key]
        _heads[key] = {slug(m.group(1)) for m in re.finditer(r"^#{1,6}\s+(.+?)\s*$", text, re.M)}
    return _heads[key]
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
        raw = md.read_text()
        # FENCED blocks first, then inline code. The inline pattern excludes newlines, so it
        # never matched a ```…``` block: a link shown as an EXAMPLE inside one was read as a
        # real link, which the header already promised never to do.
        raw = FENCE.sub(lambda m: " " * len(m.group(0)), raw)
        text = CODE.sub(lambda m: " " * len(m.group(0)), raw)
        for target in sorted(set(LINK.findall(text))):
            tgt, _, frag = target.partition("#")
            # a placeholder is a naming EXAMPLE, never a link: 0000-<slug>.md, 000Y-….md
            if any(c in target for c in "…<>*"):
                continue
            dest = md if not tgt else md.parent / tgt
            if tgt and not dest.exists():
                bad.append(f"{md}: {target}")
                continue
            # The anchor, which used to be dropped on the floor. A table of contents is a page full
            # of them, and a section renamed leaves every one of them pointing nowhere — silently,
            # since a dead anchor scrolls to the top instead of raising anything.
            if frag and dest.suffix == ".md":
                if slug(frag) not in headings(dest):
                    bad.append(f"{md}: {target} — no heading matches that anchor")

for b in bad:
    print(f"✗ dead link — {b}", file=sys.stderr)
scope = f"{files} file(s) in {', '.join(read) or 'nothing'}"
if absent:
    scope += f" — NOT read: {', '.join(absent)} (absent)"
print(f"✓ every relative link resolves — {scope}" if not bad
      else f"✗ {len(bad)} dead link(s) — {scope}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
