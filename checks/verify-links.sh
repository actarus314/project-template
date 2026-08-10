#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# Relative markdown links that resolve nowhere, and their anchors — in BOTH repos.
#
# A dead link is invisible: the reader lands nowhere and stops following pointers, hardest right
# after a move — files archived, sections renamed. Why this matters here, and the false positive
# that shaped the backtick rule below: verify-links.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (python3 absent — links not checked)"; exit 0; }

python3 - . ../workspace <<'PY'
import re, sys, pathlib

# http(s) targets stay out of scope: that uptime belongs to someone else, not this repo.
LINK = re.compile(r"\[[^\]]*\]\((?!https?:|mailto:)([^)\s]+)\)")
# Backticked text is a FORMAT EXAMPLE, not a link — `docs/X.md` must never be read as one.
CODE = re.compile(r"`[^`\n]*`")
FENCE = re.compile(r"```.*?```", re.S)

def slug(s):
    # Close to GitHub's, not identical: `\w` keeps characters GitHub strips (a circled digit, say).
    # What matters is that ONE convention applies to both sides — the anchor and the heading it
    # aims at — so a link and its target agree or they do not.
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
# Nothing here is authored: a dead link inside a dependency is not this repo's to fix.
SKIP = {".git", "node_modules", ".ci-tools", "venv"}
bad = []
# A root that is not there reads exactly like a root with nothing wrong in it, so this count is
# the only thing that tells the two apart in the verdict.
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
        raw = md.read_text()
        # FENCED blocks first, then inline code: the inline pattern excludes newlines, so on its
        # own it never matches a ```…``` block, and an example link inside one reads as real.
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
            # A dead anchor scrolls to the top instead of raising anything: silent, and a table of
            # contents is a page full of them, so a section renamed leaves every one dangling.
            if frag and dest.suffix == ".md":
                if slug(frag) not in headings(dest):
                    bad.append(f"{md}: {target} — no heading matches that anchor")

# A pointer can NAME a document and put words in its mouth, and nothing reads an attribution. Only
# a QUOTED formula counts, compared normalised — unquoted is a paraphrase, which is a judgement.
def flat(s):
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", "", s)).strip().lower()

owners, quoted = {}, 0
for root in (pathlib.Path(a) for a in sys.argv[1:]):
    for md in (root.rglob("*.md") if root.is_dir() else []):
        if not any(s in md.parts for s in SKIP):
            owners.setdefault(md.stem, md)
if owners:
    ATTR = re.compile(r"\((" + "|".join(map(re.escape, owners)) + r")(?:\.md)?\s*[:,]\s*"
                      r"[\"“«]\s*([^\"”»)]{8,90}?)\s*[\"”»]\)")
    for root in (pathlib.Path(a) for a in sys.argv[1:]):
        for src in sorted(list(root.rglob("*.md")) + list(root.rglob("*.sh")) if root.is_dir() else []):
            if any(s in src.parts for s in SKIP):
                continue
            try:
                body = src.read_text()
            except OSError:
                continue
            for doc, words in ATTR.findall(body):
                quoted += 1
                try:
                    target = flat(owners[doc].read_text())
                except OSError:
                    continue
                if flat(words) not in target:
                    bad.append(f"{src}: credits {doc}.md with \"{words}\" — that document does not say it")

for b in bad:
    print(f"✗ dead link — {b}", file=sys.stderr)
scope = f"{files} file(s) in {', '.join(read) or 'nothing'}, {quoted} quoted attribution(s)"
if absent:
    scope += f" — NOT read: {', '.join(absent)} (absent)"
print(f"✓ every relative link resolves — {scope}" if not bad
      else f"✗ {len(bad)} dead link(s) — {scope}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
