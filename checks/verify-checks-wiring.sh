#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
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

# ── 2. The hooks declare themselves, and the runner detects them ──────────────────────────────
# A hook reads its payload from STDIN: started inside the parallel lot it competes for stdin with
# every sibling, and hangs with no output. Which checks are hooks is written in ONE place — their
# own header, `# hook: <event>` — so the runner detects rather than lists, and this compares the
# detection against the declaration. It works in a generated project too, where the table is
# absent: the headers are there, and so is the runner.
self_declared = {p.stem for p in pathlib.Path("checks").glob("verify-*.sh")
                 if re.search(r"^# hook: ", p.read_text(encoding="utf-8"), re.M)}
if RUNNER.exists():
    runner = RUNNER.read_text(encoding="utf-8")
    if self_declared and "^# hook: " not in runner:
        bad.append(f"{len(self_declared)} check(s) declare themselves hooks, but {RUNNER} no longer "
                   f"detects that header — they would be started and hang on STDIN")
    read.append(f"{len(self_declared)} self-declared hook(s)")
else:
    unread.append(f"the runner's hook detection (no {RUNNER} here)")

# ── 2b. The runner READS BACK every verdict it starts ─────────────────────────────────────────
# The parallel lot writes each check's exit code to a file, and a check with no `reap` line has
# that file dropped on the floor: it runs, it is documented, it gates nothing, and every part
# above still says "wired". A check can sit in the table AND behind the door AND be unread.
# TWO shapes count as read, because there are two: the parallel lot is replayed through `reap`,
# and whatever cannot join it — verify-travel generates a whole project — is invoked directly in
# the condition of an `if`. Demanding `reap` alone accused the one check that is correctly wired.
if RUNNER.exists():
    non_hooks = {p.stem for p in pathlib.Path("checks").glob("verify-*.sh")} - self_declared
    # 🔴 The `./` is the whole discriminator, and leaving it out made this guard pass on the very
    # case it was written for: `if [ -x checks/foo.sh ]` is the EXISTENCE TEST that opens the block,
    # while `./checks/foo.sh` is the invocation whose status is read. Matching the former accepted a
    # check whose verdict was thrown away, which is a guard failing by passing.
    # Matched on CODE lines only: the literal appears in prose too, and a check merely NAMED in a
    # comment would clear this test with its verdict still on the floor.
    code = [l for l in runner.splitlines() if not l.lstrip().startswith("#")]
    def read_back(n):
        return any(f"reap {n}" in l or re.search(rf"\./checks/{re.escape(n)}\.sh", l) for l in code)
    for n in sorted(n for n in non_hooks if not read_back(n)):
        bad.append(f"{n}.sh is started but {RUNNER} never reads its verdict back — "
                   f"it is computed and thrown away")
    read.append(f"{len(non_hooks)} verdict(s) read back by {RUNNER}")
# The table says the same thing in words, for a reader. Two statements of one fact, so they are
# compared — this is the wiring this script used to be blind to.
if declared:
    table_hooks = {n for n, gate in declared.items() if gate.startswith("n/a")}
    for n in sorted(table_hooks - self_declared):
        bad.append(f"{TABLE} calls {n}.sh a hook, but its header does not declare one — "
                   f"the runner would start it")
    for n in sorted(self_declared - table_hooks):
        bad.append(f"{n}.sh declares itself a hook, but {TABLE} does not say so")

    # ── What each check says it does with a verdict, against what the table publishes ──────────
    # Same shape as the hook comparison above, for the same reason: two statements of one fact, so
    # they get compared. Three checks disagreed with themselves about blocking and nothing noticed
    # — two of them announced ADVISORY in their header for a day after being made blocking.
    # This catches the pair that DECLARE differently. The case where the code contradicts both is
    # check.sh's, at the moment the exit code exists — neither reading replaces the other.
    # Hooks are out: their column says `n/a` because check.sh renders no verdict for them, which
    # answers a different question than whether they refuse anything.
    for n in sorted(set(declared) - table_hooks):
        p = pathlib.Path("checks") / f"{n}.sh"
        if not p.exists():
            continue
        m = re.search(r"^# blocking: (yes|no)\b", p.read_text(encoding="utf-8"), re.M)
        if not m:
            bad.append(f"{n}.sh declares no `# blocking:` line — what it does with a verdict is "
                       f"then a matter of reading the code")
            continue
        gate = declared[n]
        table_blocks = gate.startswith("✅")
        if m.group(1) == "yes" and not table_blocks:
            bad.append(f"{n}.sh declares `# blocking: yes` but {TABLE} does not publish it as blocking")
        if m.group(1) == "no" and table_blocks:
            bad.append(f"{n}.sh declares `# blocking: no` but {TABLE} publishes it as blocking")
    read.append(f"{len(set(declared) - table_hooks)} blocking declaration(s) against the table")

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
