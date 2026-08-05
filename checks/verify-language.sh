#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# French left in versioned content — which is English by rule (standard §1, §15).
#
# NOTHING looked for this. verify-tone.sh is the neighbouring check and it searches for the SECOND
# PERSON, never for the language: a paragraph written entirely in French, carrying none of the
# pronouns that check hunts, passed it without a murmur. Two words shipped into published documents
# that way, and it was the maintainer who spotted them, not a control.
#
# 🔴 The signal is the ACCENT, and its limit is stated rather than hidden. Unaccented French —
# "un fichier sans accent" — goes straight through. What the accent buys is the cheap half of the
# problem, and measured across this repository it is the half that matters: of 90 accented lines,
# 65 are the two bilingual READMEs, 16 the French tracking doc the generator writes into the
# workspace, 8 the French patterns the checks must spell out and 1 the skill's trigger phrases.
# Both real slips were accented. Claiming the LANGUAGE is covered would be the only true fault
# here; what is covered is accented French, and the verdict says so in those words.
#
# ⚠ repo/ ONLY, and that is METHODE's discriminator, not an oversight. English is a rule of
# PUBLISHED STYLE, so it stops where publication stops — the neighbouring workspace/ is deliberately
# French and never leaves the machine. Extending this check there would import a rule from the one
# perimeter explicitly exempt from it. Same reasoning, same boundary as verify-tone.sh.
#
# Exceptions are DETECTED, never listed — a list of file names presumes a project keeps its
# bilingual pages where this one does:
#   · a `# … (français)` heading opens the French half of a bilingual README; everything from it
#     to the end of that file is deliberate (standard §15);
#   · a heredoc redirected into `workspace/` writes the FRENCH side, by construction;
#   · QUOTED material is verbatim and not ours to reword — a regex that must match French prose, a
#     trigger phrase the maintainer actually types, an error message quoted from a tool. Double
#     quotes and backticks are stripped before the line is judged, the same reasoning that exempts
#     licence text in verify-tone.sh;
#   · a line carrying the `fr-pattern` marker, which is verify-tone.sh's marker and not a second
#     one invented here — a check that hunts French has to spell French out.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped, and this check read NOTHING)"; exit 0; }

python3 - <<'PY'
import re, subprocess, sys, pathlib

ACCENT = re.compile(r"[àâäåçéèêëîïôöùûüÿñæœÀÂÄÅÇÉÈÊËÎÏÔÖÙÛÜŸÑÆŒ]")
FR_HALF = re.compile(r"^#{1,2} .*\(fran[çc]ais\)\s*$")
# A heredoc opening whose redirect names workspace/ — the French side, by construction.
HEREDOC = re.compile(r"<<-?\s*'?([A-Za-z_][A-Za-z0-9_]*)'?")
MARKER = "fr-pattern"   # verify-tone.sh's marker: one convention, not two
QUOTED = re.compile(r'"[^"]*"|`[^`]*`|\'[^\']*\'')

out = subprocess.run(["git", "ls-files"], capture_output=True, text=True)
if out.returncode != 0:
    print("  (not a git repository — this check read NOTHING)")
    sys.exit(0)

files = [f for f in out.stdout.splitlines() if f]
read = skipped = 0
hits = []

for f in files:
    p = pathlib.Path(f)
    try:
        text = p.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        continue                      # binary or unreadable: no prose to judge
    read += 1
    french_half = False
    heredoc_end = None                # set while inside a heredoc that writes into workspace/
    for i, line in enumerate(text.splitlines(), 1):
        if heredoc_end is not None:
            if line.strip() == heredoc_end:
                heredoc_end = None
            else:
                skipped += 1
                continue
        if FR_HALF.match(line):
            french_half = True
        if french_half:
            skipped += 1
            continue
        if "workspace/" in line:
            m = HEREDOC.search(line)
            if m:
                heredoc_end = m.group(1)
                continue
        if MARKER in line:
            skipped += 1
            continue
        # Quoted spans are verbatim material, judged by nobody here.
        bare = QUOTED.sub(" ", line)
        if ACCENT.search(bare):
            hits.append((f, i, line.strip()[:100]))

if hits:
    print(f"✗ accented French in versioned content — {len(hits)} line(s):")
    for f, i, line in hits[:20]:
        print(f"    {f}:{i}  {line}")
    if len(hits) > 20:
        print(f"    … and {len(hits) - 20} more")
    print("  Translate it, or mark the line `fr-pattern` if it must carry French to do its job.")
    sys.exit(1)

print(f"✓ no accented French in versioned content — read: {read} text file(s) in repo/, "
      f"{skipped} deliberate line(s) skipped (bilingual halves, workspace heredocs, fr-pattern markers). "
      f"Unaccented French is NOT covered.")
PY
