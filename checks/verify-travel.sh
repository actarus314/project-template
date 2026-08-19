#!/usr/bin/env bash
# blocking: yes   rule: claude-code-project-standard.md   (what this does with a verdict; compared to the control table AND to its real exit code)
# A path that resolves here but not where a generated project lands — why a grep of the tree can't
# see it, the measured differential, and why one generation isn't enough: verify-travel.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 absent — skipped"; exit 0; }

# Its subject is the generator, which a generated project does not hold — said out loud, not a silent exit.
if [ ! -f init-project.sh ]; then
  echo "  (no init-project.sh here — nothing generates projects from this repository, nothing to check)"
  exit 0
fi

# Read from init-project.sh's own `case`, never listed here (why: verify-travel.md).
# An empty read FAILS rather than skips — zero variants would find nothing and print a tick.
types=$(sed -n 's/^case "\$TYPE" in \([a-z|]*\)).*/\1/p' init-project.sh | head -1 | tr '|' ' ')
caps=$(grep -oE '^[[:space:]]+--[a-z]+\)[[:space:]]+[A-Z]+=1;' init-project.sh \
       | grep -oE '\-\-[a-z]+' | sort -u | tr '\n' ' ' || true)   # `|| true`: no capability is a legitimate read, and 0 matches would kill the script before the message below
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
  # stdout muted here only (init-project.sh's next-steps guide; errors stay on stderr) — the
  # variant is NAMED in the failure below, so a dead generation still says which one (why: verify-travel.md).
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
# Nothing here is authored, so no path in it travels: skipped rather than reported.
SKIP = {".git", "node_modules", ".ci-tools", "venv"}
norm = lambda p: p[2:] if p.startswith("./") else p

# Keyed by (file, path): the same dead path in one file is ONE defect, listed with every variant
# that saw it (why this shape: verify-travel.md).
hits = {}
for label, gendir in gens:
    gen = pathlib.Path(gendir)
    for g in sorted(p for p in gen.rglob("*") if p.is_file() and not any(s in p.parts for s in SKIP)):
        try:
            text = g.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        # A file that TESTS a path knows it may be missing: a shell test (negated or not), a
        # Python existence test, or a literal bound to a name tested elsewhere (why: verify-travel.md).
        guarded = {norm(p) for line in text.splitlines()
                   if re.search(r"\[\s+!?\s*-[fxeds]\s|\.(?:exists|is_file|is_dir)\(\)", line)
                   for p in LOOSE.findall(line)}
        tested = set(re.findall(r'\[\s+!?\s*-[fxeds]\s+"?\$\{?([A-Za-z_][A-Za-z0-9_]*)', text))
        tested |= set(re.findall(r'\b([A-Za-z_][A-Za-z0-9_]*)\.(?:exists|is_file|is_dir)\(\)', text))
        if tested:
            names = "|".join(re.escape(n) for n in tested)
            assign = re.compile(r'\b(?:' + names + r')\s*=\s*(?:pathlib\.Path\()?["\']?'
                                r'([A-Za-z0-9_./-]+\.(?:' + EXT + r'))')
            guarded |= {norm(m) for m in assign.findall(text)}
        # Testing the FOLDER guards everything under it — a stronger statement than testing each path.
        guarded_dirs = {d.rstrip("/") for d in
                        re.findall(r'\[\s+!?\s*-d\s+"?([A-Za-z0-9_./-]+)', text)}
        for m in sorted({norm(p) for p in PATH.findall(text)} - guarded):
            if any(m.startswith(d + "/") for d in guarded_dirs):
                continue
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
