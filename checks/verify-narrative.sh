#!/usr/bin/env bash
# Dated narrative in a code comment — forbidden by METHODE.md.
#
# The code says what it DOES. A comment says only what the code cannot say: a constraint that
# would otherwise recur. The story of how a defect was found — the date, the incident, the
# evidence — belongs to the archive, where it is dated, sourced and immutable.
#
# 🔴 THE RULE HELD BY DISCIPLINE ALONE, AND DISCIPLINE DOES NOT HOLD. The inventory recorded it
# as "already respected, nothing to build" — on a snapshot taken right after a manual review pass.
# That measured a rule freshly tidied, not a rule kept. Three violations appeared within hours,
# in the very scripts written to enforce other rules. The same story as verify-tone.sh.
#
# THE DISCRIMINATOR, and it comes from the one conforming case rather than from theory:
#
#   # (Full-Renovate switch, 2026-07 — see workspace/archives/2026-07-autodetection/SYNTHESE.md.)
#
# A date is allowed IFF the same line points into `archives/`. One line, one pointer, the story
# lives where stories live. Anything else with a date in a comment is the narrative itself.
#
# Scope: every COMMENTED line of every tracked text file. Not prose — a CHANGELOG, a runbook and
# an archive carry dates by design.
#
# 🔴 The comment marker is per LANGUAGE, and that is not a refinement. This check TRAVELS into
# every generated project, and it used to scan `*.sh *.yml *.yaml` only: in a Python, TypeScript
# or Go project it read nothing at all and reported "no dated narrative" over a repository it had
# never opened. A guard that travels must not assume the language of the place it lands in.
#
# The marker is not anchored to the start of the line either: a trailing comment carrying a date is the
# same violation, and an anchored pattern walks straight past it.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# `git grep` on purpose, like verify-tone.sh: the rule is about what is COMMITTED. An untracked
# scratch file breaking it is nobody's business.
scan() { git -C "$1" ls-files -z 2>/dev/null \
         | MARK_PREFIX="$2" python3 -c '
import os, re, sys, pathlib

# extension (or bare name) -> the marker that opens a line comment there.
BY_NAME = {".gitignore":"#", ".gitattributes":"#", ".envrc":"#", ".dockerignore":"#",
           ".editorconfig":"#", "Makefile":"#"}
BY_EXT = {**dict.fromkeys("sh bash zsh py rb pl r yml yaml toml tf nix jl ps1 cmake mk".split(), "#"),
          **dict.fromkeys("js mjs cjs jsx ts tsx go rs java kt swift c h cc cpp hpp cs scala dart php proto gradle".split(), "//"),
          **dict.fromkeys("sql hs lua elm ada".split(), "--"),
          **dict.fromkeys("el lisp clj ini".split(), ";")}
DATE = re.compile(r"20[0-9]{2}-[0-9]{2}")
prefix = os.environ.get("MARK_PREFIX", "")
unknown = set()   # languages this run could not read, published below rather than swallowed

for f in sys.stdin.buffer.read().split(b"\0"):
    if not f:
        continue
    name = f.decode("utf-8", "replace")
    base = pathlib.PurePath(name).name
    mark = BY_NAME.get(base) or (BY_EXT.get(name.rsplit(".", 1)[-1]) if "." in base else
                                 ("#" if base.startswith("Dockerfile") else None))
    if not mark:
        # ASK THE FILE. A name carries no extension precisely where it matters most — `pre-commit`
        # and `pre-push` are shell, and neither was being read at all. A shebang is the file
        # declaring its own language, which no list here can keep up with.
        try:
            head = pathlib.Path(name).open("rb").readline(200).decode("utf-8", "replace")
        except Exception:
            head = ""
        if head.startswith("#!"):
            mark = "#"   # every #!-interpreted language this repo can hold comments with #
    if not mark:
        # PUBLISHED, never swallowed. A language with no known marker is a file this check did NOT
        # read, and a silent skip there reads exactly like a clean file — proven on a `.zig` holding
        # a dated comment, which came back clean.
        unknown.add(name.rsplit(".", 1)[-1] if "." in base else base)
        continue
    try:
        text = pathlib.Path(name).read_text(encoding="utf-8", errors="replace")
    except Exception:
        continue
    for n, line in enumerate(text.splitlines(), 1):
        i = line.find(mark)
        if i < 0:
            continue
        if DATE.search(line[i:]):
            print(f"{prefix}{name}:{n}:{line.strip()[:150]}")
# STDERR, not stdout: stdout is captured as the list of violations, and an extra line there would
# read as one.
if unknown:
    label = prefix or "repo/"
    print("  (" + label + ": extensions with no known comment marker, not examined: "
          + " ".join(sorted(unknown)) + ")", file=sys.stderr)
'; }

# METHODE holds for BOTH repos: repo/ and the neighbouring workspace/, which has its own git.
# The tone rule stays repo-only (workspace/ is deliberately French, and that rule imposes English),
# but a dated narrative in a comment is a METHOD rule — it applies wherever code lives.
# Counted per side. "repo/ and workspace/" says which trees were INTENDED; only a count says
# whether either held a file with a comment marker at all.
count_src() { git -C "$1" ls-files 2>/dev/null | grep -cE '\.[A-Za-z0-9]+$' || true; }
scope="repo/ $(count_src .) tracked file(s)"
[ -d ../workspace ] && scope="$scope, workspace/ $(count_src ../workspace) tracked file(s)"
hits=$( { scan . ''; [ -d ../workspace ] && scan ../workspace '../workspace/'; } | grep -v 'archives/' || true)

if [ -z "$hits" ]; then
  # The perimeter is published with the verdict: a neighbour that is not there and a neighbour with
  # nothing to report produced the same tick, and this check TRAVELS, where it lands beside no
  # workspace at all.
  echo "✓ no dated narrative in code comments — read: $scope"
  exit 0
fi

echo "$hits" >&2
cat >&2 <<'EOF'

✗ dated narrative in a code comment — it belongs in the archive.
  Keep in the comment ONLY what the code cannot say. Move the account to
  workspace/archives/<stage>/, and leave a one-line pointer:
      # (What happened, in three words — see workspace/archives/<stage>/SYNTHESE.md.)
  A date is allowed only on a line that points into archives/.
EOF
exit 1
