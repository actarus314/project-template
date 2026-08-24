#!/usr/bin/env bash
# blocking: yes   rule: METHODE.md   (what this does with a verdict; compared to the control table AND to its real exit code)
# The memories: index complete, no broken [[link]] or index entry pointing nowhere, no dead path.
#
# LOCAL-ONLY by nature — they live outside the repo, under ~/.claude/projects/<slug>/memory/, where
# <slug> is the project's absolute path with every / turned into a dash. Why that matters more than
# it looks, and the tick this script refuses to print for free: verify-memories.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

slug=${PWD//\//-}
dir="$HOME/.claude/projects/$slug/memory"
[ -d "$dir" ] || { echo "  (no memories for this project — nothing to check: $dir)"; exit 0; }
[ -f "$dir/MEMORY.md" ] || { echo "✗ $dir has memories but no MEMORY.md index" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || { echo "  (python3 absent — memories not checked)"; exit 0; }

python3 - "$dir" "$(cd .. && pwd)" <<'PY'
import os, re, sys, pathlib
d, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
index = (d / "MEMORY.md").read_text()
names = {p.stem for p in d.glob("*.md") if p.name != "MEMORY.md"}

bad = []
# 1. every memory reachable from the index — one absent is never recalled
for n in sorted(names):
    if f"({n}.md)" not in index:
        bad.append(f"{n}.md is not in MEMORY.md — it will never be recalled")
# 2. every index target exists
for t in sorted(set(re.findall(r"\]\(([a-z0-9-]+\.md)\)", index))):
    if not (d / t).exists():
        bad.append(f"MEMORY.md points at {t}, which does not exist")
# 3. every [[wiki-link]] resolves
for p in sorted(d.glob("*.md")):
    for link in sorted(set(re.findall(r"\[\[([a-z0-9-]+)\]\]", p.read_text()))):
        if link not in names:
            bad.append(f"{p.name} links to [[{link}]], which does not exist")

# 4. every LITERAL project path resolves — a memory links to no file, so nothing else sees one rot.
# A placeholder, a glob and a `file:line` are excluded: resolving one would be a judgement.
PATH_LIKE = re.compile(r"^(?:workspace|repo|archives)/\S+|^~/\.claude/\S+")
NOT_A_PATH = re.compile(r"[…<>*]|:\d+$")
paths = 0
for p in sorted(d.glob("*.md")):
    for tok in sorted(set(re.findall(r"`([^`\n]+)`", p.read_text()))):
        tok = tok.strip().rstrip(".,;:)")
        if not PATH_LIKE.match(tok) or NOT_A_PATH.search(tok):
            continue
        paths += 1
        if tok.startswith("~"):
            target = pathlib.Path(os.path.expanduser(tok))
        elif tok.startswith("archives/"):
            target = root / "workspace" / tok
        else:
            target = root / tok
        if not target.exists():
            bad.append(f"{p.name} points at {tok}, which does not exist")

for b in bad:
    print(f"✗ {b}", file=sys.stderr)
print(f"✓ {len(names)} memories: indexed, links resolve, {paths} project path(s) resolve" if not bad
      else f"✗ {len(bad)} problem(s) across {len(names)} memories", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
