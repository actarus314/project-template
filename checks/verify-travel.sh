#!/usr/bin/env bash
# A path that resolves HERE but not where the file LANDS.
#
# Several files travel into every generated project — check.sh, verify-tone.sh, everything under
# templates/. A path written in one of them is read by whoever has THAT copy in front of them, in a
# project that holds neither docs/ nor templates/.
#
# ⚠ A grep of the tree cannot see this. It proves no file NAMES a deleted doc; it is blind to a
#   path that stays written and simply resolves nowhere once it has travelled.
#   (That blindness cost two fixes — see workspace/archives/2026-08-decoupage-par-sujet/SYNTHESE.md.)
#
# So the only way to see it is to GENERATE a project and read the paths from THERE.
#
# The signal is a DIFFERENTIAL, and that is what keeps it quiet: a path is reported only when it
# resolves in the template AND fails in the generated project. A generic pattern (docs/X.md), a
# naming example (docs/adr/0001-short-title.md) or a URL resolves in neither, so none of them shows
# up. Measured: 0 reported on a healthy state, 1 on the real defect.
#
# 🔴 ONE GENERATION IS NOT ENOUGH, and for two opposite reasons.
#   · Because the signal is a differential, the POOREST tree is the harshest: `generic` ships no
#     capability at all, so a path that survives everywhere else dies there.
#   · And a capability brings FILES OF ITS OWN — pages.yml, docker-publish.yml — whose paths are
#     read by nobody unless a variant carrying them is generated.
#   This is not combinatorics: what has to be covered is the set of files that can LAND, not the
#   set of flag combinations. One generation per toolchain, plus one carrying every capability at
#   once, is what reaches every file.
#   (What a single `--type node` run left unread — see workspace/archives/2026-08-audit-des-controles/SYNTHESE.md.)
#
# To declare a path deliberately absent from a generated project, TEST it — `[ -f x ]`, `[ -x x ]`.
# A file that checks a path's existence knows it may be missing, and this script honours that.
#
# Usage:
#   ./verify-travel.sh          # generates the variants, compares, cleans up; exits 1 on a find
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 absent — skipped"; exit 0; }

# The toolchains and the capabilities are READ from init-project.sh, never listed here: the `case`
# that VALIDATES --type is what decides them, so one added there is covered the day it is accepted.
# 🔴 An empty read FAILS the check rather than skipping it — zero variants would generate nothing,
# find nothing, and print a tick, which is exactly how a guard goes green and blind.
types=$(sed -n 's/^case "\$TYPE" in \([a-z|]*\)).*/\1/p' init-project.sh | head -1 | tr '|' ' ')
caps=$(grep -oE '^[[:space:]]+--[a-z]+\)[[:space:]]+[A-Z]+=1;' init-project.sh \
       | grep -oE '\-\-[a-z]+' | sort -u | tr '\n' ' ')
[ -n "$types" ] || { echo "✗ cannot read the toolchains from init-project.sh — this check would pass by looking at nothing" >&2; exit 1; }
[ -n "$caps" ]  || { echo "✗ cannot read the capabilities from init-project.sh — same reason" >&2; exit 1; }

VARIANTS=()
for t in $types; do VARIANTS+=("$t|--type $t"); done
first=${types%% *}
VARIANTS+=("$first+all|--type $first $caps")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gens=()
for v in "${VARIANTS[@]}"; do
  label="${v%%|*}"; args="${v#*|}"
  # stdout is muted on purpose HERE and nowhere else: what matters is the generated tree, and
  # init-project.sh prints the whole next-steps guide. Its errors stay on stderr and stay visible.
  # The variant is NAMED in the failure: a generation that dies without saying which combination
  # died is the "a failing check does not say why" defect, one level up.
  # shellcheck disable=SC2086  # $args is a flag list, word splitting is what makes it one
  if ! ./init-project.sh travelprobe actarus314/travelprobe "$tmp/$label" $args >/dev/null; then
    echo "✗ generation failed for variant '$label' ($args) — cannot check travelling paths" >&2
    exit 1
  fi
  gens+=("$label=$tmp/$label/travelprobe/repo")
done

python3 - "$PWD" "${gens[@]}" <<'PY'
import re, sys, pathlib
repo = pathlib.Path(sys.argv[1])
gens = [a.split("=", 1) for a in sys.argv[2:]]
EXT = "md|sh|yml|yaml|json|txt|html|py"
PATH = re.compile(r"(?<![\w./-])((?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.(?:" + EXT + r"))")
LOOSE = re.compile(r"[A-Za-z0-9_./-]+\.(?:" + EXT + r")")
SKIP = {".git", "node_modules", ".ci-tools", "venv"}
norm = lambda p: p[2:] if p.startswith("./") else p

# Keyed by (file, path): the same dead path in one file is ONE defect however many variants show
# it, while the same path in two files is two. The variants that saw it are listed with it —
# a path dying only under `generic` is a different fact from one dying everywhere.
hits = {}
for label, gendir in gens:
    gen = pathlib.Path(gendir)
    for g in sorted(p for p in gen.rglob("*") if p.is_file() and not any(s in p.parts for s in SKIP)):
        try:
            text = g.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        guarded = {norm(p) for line in text.splitlines() if re.search(r"\[\s+-[fxeds]\s", line)
                   for p in LOOSE.findall(line)}
        for m in sorted({norm(p) for p in PATH.findall(text)} - guarded):
            if not (gen / m).exists() and (repo / m).exists():
                hits.setdefault((str(g.relative_to(gen)), m), []).append(label)

for (f, m), labels in sorted(hits.items()):
    print(f"✗ {f} points at {m}, which exists here but NOT in a generated project "
          f"({', '.join(labels)})", file=sys.stderr)
scope = f"{len(gens)} variant(s): {', '.join(l for l, _ in gens)}"
print(f"✓ no path dies on landing — {scope}" if not hits
      else f"✗ {len(hits)} travelling path(s) resolve here and nowhere else — {scope}",
      file=sys.stderr)
sys.exit(1 if hits else 0)
PY
