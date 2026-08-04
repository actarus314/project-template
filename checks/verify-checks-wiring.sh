#!/usr/bin/env bash
# Every check is declared, and every hand-written list obeys that declaration.
#
# 🔴 Three lists name the checks one by one: the CI steps, the files init-project.sh copies into a
# generated project, and the table in METHODE.md. A check added, renamed or moved has to be carried
# into all three by hand — and the failure is SILENT in every direction: a check missing from the CI
# passes no gate, a check missing from init-project.sh ships nowhere, a check missing from the table
# is armed but undocumented. Each of those has already happened here.
#
# Auto-detecting the CI list is not the answer: four checks have no business there, because their
# subject lives outside the repository or because they are advisory on purpose. That exception is
# already WRITTEN DOWN, in the METHODE table — so the table is the source, and this compares the
# lists against it rather than against a guess.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped)"; exit 0; }

python3 - <<'PY'
import re, pathlib, sys

METHODE = pathlib.Path("docs/METHODE.md")
CI      = pathlib.Path(".github/workflows/ci.yml")
INIT    = pathlib.Path("init-project.sh")
bad = []

if not METHODE.exists():
    print("  (no docs/METHODE.md — skipped)"); sys.exit(0)
methode = METHODE.read_text(encoding="utf-8")

# The table rows: first cell names one or more scripts, last cell says whether the CI runs it.
# A row may carry two scripts on one line, so every name in the first cell is taken.
declared = {}
for row in re.findall(r"^\|\s*`checks/.+\|\s*$", methode, re.M):
    # .strip() BEFORE stripping the pipes. `\s*$` is greedy and swallows the newline on the LAST
    # row of the table, so the closing pipe is no longer final and survives strip("|") — that row
    # alone then splits into an extra, empty cell, and its verdict reads as absent. The bug hits
    # exactly one row, the last, and moving a row cures it while changing nothing.
    cells = [c.strip() for c in row.strip().strip("|").split("|")]
    names = re.findall(r"(verify-[a-z-]+)\.sh", cells[0])
    gated = cells[-1].startswith("✅")
    for n in names:
        declared[n] = gated

on_disk = {p.stem for p in pathlib.Path("checks").glob("verify-*.sh")}

for n in sorted(on_disk - set(declared)):
    bad.append(f"checks/{n}.sh exists but has no row in the METHODE table — armed and undocumented")
for n in sorted(set(declared) - on_disk):
    bad.append(f"the METHODE table lists {n}.sh, which no longer exists under checks/")

# The CI list: only what a `run:` actually invokes. A name appearing in a comment is not a step.
ci_runs = set()
if CI.exists():
    for line in CI.read_text(encoding="utf-8").splitlines():
        if re.match(r"\s*run:", line) or re.match(r"\s+\./checks/", line):
            ci_runs |= {m for m in re.findall(r"checks/(verify-[a-z-]+)\.sh", line)}

for n in sorted(set(declared) & on_disk):
    if declared[n] and n not in ci_runs:
        bad.append(f"{n}.sh is declared as running at the gate (✅) but no CI step invokes it")
    if not declared[n] and n in ci_runs:
        bad.append(f"{n}.sh is declared as NOT running at the gate but a CI step invokes it")

# The travelling checks: the table's own paragraph names them, and init-project.sh copies them.
# Two hand-written lists for one fact — so they have to agree.
para = re.search(r"travel into a generated project[^|]*", methode)
if para:
    travel_declared = {m for m in re.findall(r"(verify-[a-z-]+)\.sh", para.group(0))}
    travel_copied = set()
    if INIT.exists():
        travel_copied = {m for m in re.findall(r'checks/(verify-[a-z-]+)\.sh"\s+"\$DEST', INIT.read_text(encoding="utf-8"))}
    for n in sorted(travel_declared - travel_copied):
        bad.append(f"{n}.sh is declared as travelling, but init-project.sh does not copy it")
    for n in sorted(travel_copied - travel_declared):
        bad.append(f"init-project.sh copies {n}.sh into generated projects, undeclared in METHODE")

for b in bad:
    print(f"✗ {b}")
if not bad:
    print(f"✓ {len(on_disk)} checks: each declared, each wired as declared")
sys.exit(1 if bad else 0)
PY
