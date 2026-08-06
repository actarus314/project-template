#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A comment block deleted with nowhere to say where it went. Why it asks for a DECLARATION rather
# than measuring whether the text reappeared: docs/code/verify-dropped-comment.md
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# The same reference as verify-comment-drift.sh, for the same reason — one rule, one anchor.
ref=$(git rev-parse --verify --quiet origin/main >/dev/null 2>&1 && echo origin/main \
      || git describe --tags --abbrev=0 2>/dev/null || true)
[ -n "$ref" ] || { echo "  (no reference point yet — nothing to compare against)"; exit 0; }

BLOCK=${DROPPED_BLOCK_THRESHOLD:-5}
command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped)"; exit 0; }

python3 - "$ref" "$BLOCK" <<'PY'
import re, subprocess, sys, pathlib

ref, block = sys.argv[1], int(sys.argv[2])
CODE = re.compile(r"\.(sh|py|ya?ml)$")


def run(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


# COMMITS only, never the working tree: the `drop:` declaration lives in a commit message, and a
# pre-commit hook cannot read the message of the commit being made (verified: COMMIT_EDITMSG does
# not exist yet at that point). Judging the working tree would refuse a declaration correctly
# written. The CI sees the whole branch before any merge, and it is the authority.
diff = run("git", "diff", "-U0", f"{ref}...HEAD")
touched = set(run("git", "diff", "--name-only", f"{ref}...HEAD").split())
# A note written for THIS branch may not be tracked yet, and an untracked file is in no diff.
touched |= set(run("git", "ls-files", "--others", "--exclude-standard").split())

# `drop:` in any commit message of the branch — the declaration that a passage was deleted on
# purpose. It names what went, so the decision is readable later; the check never judges the reason.
declared = "drop:" in run("git", "log", "--format=%B", f"{ref}..HEAD").lower()

dropped, path, size = [], None, 0
for line in diff.splitlines():
    if line.startswith("+++ b/"):
        if path and size >= block:
            dropped.append((path, size))
        path, size = line[6:], 0
    elif path and CODE.search(path) and re.match(r"^-\s*#", line):
        size += 1
    elif size:
        if path and size >= block:
            dropped.append((path, size))
        size = 0
if path and size >= block:
    dropped.append((path, size))

unexplained = []
for p, n in dropped:
    note = f"docs/code/{pathlib.Path(p).stem}.md"
    if note in touched or declared:
        continue
    unexplained.append((p, n, note))

if not unexplained:
    kept = len(dropped) - len(unexplained)
    print(f"✓ every deleted comment block is accounted for — read: {len(dropped)} block(s) of "
          f"{block}+ lines removed since {ref}, {kept} with a note or a declaration")
    sys.exit(0)

for p, n, note in unexplained:
    print(f"  ↑ {p:<40} {n} comment lines deleted, and {note} was not touched", file=sys.stderr)
print("""
  A deleted passage is a DECISION, and this asks which one it was:
    · it should never have been written there -> `drop: <what went, and why>` in a commit message;
    · it belongs to its own note              -> it MOVES into docs/code/<name>.md, rewritten to
      fit its new home if that is what it takes;
    · it belongs to another owner             -> move it there, and name that in the same
      `drop:` line — this check knows one destination, METHODE.md decides the real one.
  Neither deleting nor keeping is the default. What this refuses is a passage that just vanishes.""", file=sys.stderr)
sys.exit(1)
PY
