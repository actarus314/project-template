#!/usr/bin/env bash
# The checks are declared, and the DOOR that runs them is where it is supposed to be.
#
# 🔴 The failure this exists for is silent in every direction. A check nobody calls passes no gate,
# and reads exactly like a check that found nothing. That has happened here more than once.
#
# What it compares has changed with the door itself. There used to be three hand-written lists
# naming the checks one by one — the CI steps, the files init-project.sh copied, the table — and
# keeping three lists agreeing was the whole job. There is now ONE line, `check.sh --house`, behind
# which everything under checks/ runs. So the question is no longer "is each check in each list"
# but "is the door there, in every workflow that gates a project".
#
# It travels, like every other check, and it works on both sides of that trip:
#   · here, it sees the control table, the shipped workflow templates and the generator;
#   · in a generated project, none of those exist — but its ci.yml does, and the door must be in it.
# Each part states whether it had anything to look at. A part with no subject says so.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped)"; exit 0; }

python3 - <<'PY'
import re, pathlib, sys

DOOR   = "check.sh --house"
TABLE  = pathlib.Path("docs/repo-controls.md")
RUNNER = pathlib.Path("check.sh")
INIT   = pathlib.Path("init-project.sh")
bad, read, unread = [], [], []

on_disk = {p.stem for p in pathlib.Path("checks").glob("verify-*.sh")}
if not on_disk:
    print("✗ no checks/verify-*.sh here — this check would pass by looking at nothing")
    sys.exit(1)

# ── 1. Every check is declared in the table, and every declared check exists ───────────────────
# The table is this repository's; a generated project holds no copy of it, and must not be asked
# to account for a document it was never given.
declared = {}
if TABLE.exists():
    table = TABLE.read_text(encoding="utf-8")
    for row in re.findall(r"^\|\s*`checks/.+\|\s*$", table, re.M):
        # .strip() BEFORE stripping the pipes: `\s*$` swallows the newline on the table's LAST row,
        # so its closing pipe is no longer final, survives strip("|"), and that row alone splits
        # into an extra empty cell whose verdict then reads as absent.
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        for n in re.findall(r"(verify-[a-z-]+)\.sh", cells[0]):
            declared[n] = cells[-1]
    for n in sorted(on_disk - set(declared)):
        bad.append(f"checks/{n}.sh exists but has no row in {TABLE} — armed and undocumented")
    for n in sorted(set(declared) - on_disk):
        bad.append(f"{TABLE} lists {n}.sh, which no longer exists under checks/")
    read.append(f"the control table ({len(declared)} declared)")
else:
    unread.append(f"the control table ({TABLE} is this repository's own, absent here)")

# ── 2. The hooks the table calls "n/a" are exactly the ones the runner keeps out ───────────────
# A hook reads its payload from STDIN: started inside the parallel lot it competes for stdin with
# every sibling. Which ones they are is stated in the table and applied in check.sh — two places,
# so they are compared rather than trusted. This is the wiring this script used to be blind to.
if declared and RUNNER.exists():
    table_hooks = {n for n, gate in declared.items() if gate.startswith("n/a")}
    runner = RUNNER.read_text(encoding="utf-8")
    # An UNCONDITIONAL skip only: `) continue;;`. The lines carrying `touched` are the second
    # rhythm — those checks run whenever their own target moved, and counting them as excluded
    # inflated the figure this very script publishes.
    excluded = set()
    for line in runner.splitlines():
        if "continue;;" in line and "verify-" in line and "touched" not in line:
            excluded |= set(re.findall(r"(verify-[a-z-]+)\.sh", line))
    # verify-travel is kept out of the parallel lot for its own reason (it generates projects) and
    # is called back further down, so it is excluded WITHOUT being a hook. Only a hook that the
    # runner would START is a defect, and a non-hook the runner never runs at all.
    started_hooks = table_hooks - excluded
    if started_hooks:
        bad.append(f"{', '.join(sorted(started_hooks))}: the table calls them hooks (n/a), "
                   f"but {RUNNER} starts them — they read STDIN and would fight for it")
    never_run = excluded - table_hooks - {"verify-travel"}
    for n in sorted(never_run):
        if declared.get(n, "").startswith("✅"):
            bad.append(f"{n}.sh is declared as running at the gate but {RUNNER} skips it entirely")
    read.append(f"the runner's hook exclusions ({len(excluded)})")
elif not RUNNER.exists():
    unread.append(f"the runner's hook exclusions (no {RUNNER} here)")

# ── 3. THE DOOR — every workflow that gates a project calls it ────────────────────────────────
# This is the part that says something everywhere. A generated project holds no table and no
# generator, but it holds the workflow that must run its checks, and that workflow going quiet is
# the exact defect this whole arrangement exists to prevent: shipped, executable, never run.
gates = sorted(pathlib.Path(".github/workflows").glob("ci*.yml")) if pathlib.Path(".github/workflows").is_dir() else []
gates += sorted(pathlib.Path("templates/workflows").glob("ci-*.yml")) if pathlib.Path("templates/workflows").is_dir() else []
if gates:
    for g in gates:
        if DOOR not in g.read_text(encoding="utf-8"):
            bad.append(f"{g} runs no `{DOOR}` — the checks it should gate would ship and never run")
    read.append(f"{len(gates)} gating workflow(s): {', '.join(str(g) for g in gates)}")
else:
    unread.append("the gating workflows (no .github/workflows/ci*.yml, no templates/workflows/)")

# ── 4. The generator ships checks/ whole, never a hand-picked list ────────────────────────────
if INIT.exists():
    init = INIT.read_text(encoding="utf-8")
    if not re.search(r'cp\s+"\$TPL/checks/"verify-\*\.sh', init):
        bad.append(f"{INIT} no longer copies checks/ as a whole — a hand-picked list is how "
                   f"fifteen checks stayed behind")
    read.append("the generator's copy of checks/")
else:
    unread.append(f"the generator's copy of checks/ (no {INIT} here)")

for b in bad:
    print(f"✗ {b}")
if not bad:
    print(f"✓ {len(on_disk)} checks, and the door is wired — read: {'; '.join(read)}")
if unread:
    print(f"  NOT read: {'; '.join(unread)}")
sys.exit(1 if bad else 0)
PY
