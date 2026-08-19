#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   (what this does with a verdict; compared to the control table AND to its real exit code)
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

# Adjustable. Below this, a removal is an edit, not a block going missing: verify-dropped-comment.md.
BLOCK=${DROPPED_BLOCK_THRESHOLD:-5}
command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped)"; exit 0; }

python3 - "$ref" "$BLOCK" <<'PY'
import re, subprocess, sys, pathlib

ref, block = sys.argv[1], int(sys.argv[2])
# `#`-commented languages only: the three this repo and its generated projects actually ship. A
# `//` or `--` dialect appearing here would be a new kind of file, and a check silently covering
# nothing is worse than one whose perimeter is stated.
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

# `drop:` in a commit message declares a deletion made on purpose. A declaration covers ONLY the
# files it NAMES: one blanket `drop:` used to exempt every block on the branch, which is a
# maximal-scope exception hiding inside a minimal-scope mechanism (found by a third-party sweep the
# day this check was written, on this check's own first commit — 1 declaration, 19 blocks passed).
# The check reads which files are named; it never judges the reason given.
# A declaration is the PARAGRAPH it opens, never its first line — see this check's note.
declarations = [p for p in re.split(r"\n\s*\n", run("git", "log", "--format=%B", f"{ref}..HEAD"))
                if "drop:" in p.lower()]


def declared_for(p):
    """A declaration names the file when it carries its path or its bare name."""
    stem = pathlib.Path(p).name
    return any(p in d or stem in d for d in declarations)

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
    if note in touched or declared_for(p):
        continue
    unexplained.append((p, n, note))

if not unexplained:
    kept = len(dropped) - len(unexplained)
    print(f"✓ every deleted comment block is accounted for — read: {len(dropped)} block(s) of "
          f"{block}+ lines removed since {ref}, {kept} with a note or a declaration")
    sys.exit(0)

for p, n, note in unexplained:
    print(f"  ↑ {p:<40} {n} comment lines deleted — neither {note} touched, "
          f"nor a `drop:` line naming {pathlib.Path(p).name}", file=sys.stderr)
print("""
  A deleted passage is a DECISION, and this asks which one it was:
    · it should never have been written there -> `drop: <file>, what went and why` in a commit
      message. It covers ONLY the files it NAMES — one blanket line does not clear a branch;
    · it belongs to its own note              -> it MOVES into docs/code/<name>.md, rewritten to
      fit its new home if that is what it takes;
    · it belongs to another owner             -> move it there, and name that in the same
      `drop:` line — this check knows one destination, METHODE.md decides the real one.
  Neither deleting nor keeping is the default. What this refuses is a passage that just vanishes.""", file=sys.stderr)
sys.exit(1)
PY
