#!/usr/bin/env bash
# A path that resolves HERE but not where the file LANDS.
#
# Several files travel into every generated project — check.sh, verify-tone.sh, everything under
# templates/. A path written in one of them is read by whoever has THAT copy in front of them, in a
# project that holds neither docs/ nor templates/.
#
# ⚠ A grep of the tree cannot see this. It proves no file NAMES a deleted doc; it is blind to a
#   path that stays written and simply resolves nowhere once it has travelled. That blindness cost
#   two fixes on 2026-08-03: verify-tone.sh pointed at docs/repo-controls.md, absent from every
#   generated project, and the new-project skill read its docs from the session's cwd.
#
# So the only way to see it is to GENERATE a project and read the paths from THERE.
#
# The signal is a DIFFERENTIAL, and that is what keeps it quiet: a path is reported only when it
# resolves in the template AND fails in the generated project. A generic pattern (docs/X.md), a
# naming example (docs/adr/0001-short-title.md) or a URL resolves in neither, so none of them shows
# up. Measured: 0 reported on a healthy state, 1 on the real defect.
#
# To declare a path deliberately absent from a generated project, TEST it — `[ -f x ]`, `[ -x x ]`.
# A file that checks a path's existence knows it may be missing, and this script honours that.
#
# Usage:
#   ./verify-travel.sh          # generates a throwaway project, compares, cleans up; exits 1 on a find
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 absent — skipped"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# stdout is muted on purpose HERE and nowhere else: what matters is the generated tree, and
# init-project.sh prints the whole next-steps guide. Its errors stay on stderr and stay visible.
if ! ./init-project.sh travelprobe actarus314/travelprobe "$tmp" --type node >/dev/null; then
  echo "✗ generation failed — cannot check travelling paths" >&2
  exit 1
fi

python3 - "$PWD" "$tmp/travelprobe/repo" <<'PY'
import re, sys, pathlib
repo, gen = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
EXT = "md|sh|yml|yaml|json|txt|html|py"
PATH = re.compile(r"(?<![\w./-])((?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.(?:" + EXT + r"))")
LOOSE = re.compile(r"[A-Za-z0-9_./-]+\.(?:" + EXT + r")")
SKIP = {".git", "node_modules", ".ci-tools", "venv"}
norm = lambda p: p[2:] if p.startswith("./") else p

hits = []
for g in sorted(p for p in gen.rglob("*") if p.is_file() and not any(s in p.parts for s in SKIP)):
    try:
        text = g.read_text()
    except (UnicodeDecodeError, OSError):
        continue
    guarded = {norm(p) for line in text.splitlines() if re.search(r"\[\s+-[fxeds]\s", line)
               for p in LOOSE.findall(line)}
    for m in sorted({norm(p) for p in PATH.findall(text)} - guarded):
        if not (gen / m).exists() and (repo / m).exists():
            hits.append((str(g.relative_to(gen)), m))

for f, m in hits:
    print(f"✗ {f} points at {m}, which exists here but NOT in a generated project", file=sys.stderr)
print("✓ no path dies on landing" if not hits
      else f"✗ {len(hits)} travelling path(s) resolve here and nowhere else", file=sys.stderr)
sys.exit(1 if hits else 0)
PY
