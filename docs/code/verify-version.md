# `checks/verify-version.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The single source is the git tag

That the tag is the single source, and why, belong elsewhere. **What this script owns is the
consequence**: everything able to READ the tag does so, so the only possible drift sits in the
places that must carry a COPY by their nature — and those three are exactly what it compares: the
CHANGELOG heading, each shipped script's own `--version` answer, and the plugin manifest.

## Each shipped script must print the version

DERIVED, never written, and with NO extension filter: what git tracks as EXECUTABLE, whatever the
language. Filtering on `*.sh` would presume the project is written in shell, which this template
travels far past.

The pattern matches a HANDLER, never a mention: `check.sh` names `--version` in a comment and
answers it by running the whole lot, which a looser grep would then execute. Shell, Python, Node,
Go and Java forms are recognised.

🔴 A COMPILED executable cannot be grepped at all — there is no source to match. Those are counted
and NAMED as unexamined instead of being silently cleared, which is what the verdict used to do
while its own comment claimed the opposite.

## The parallel ask, and its two pitfalls

Every script is asked for its version in PARALLEL, and answers are read back in order — through
files, never a pipe, because interleaved writes from concurrent jobs are what makes a parallel loop
report the wrong script's version.

Two pitfalls inside that loop:

- **STDIN closed.** Three of the shipped scripts are hooks that read their payload from stdin, and
  asking a script for its version must never leave one of them waiting on the terminal — inside
  `check.sh`'s parallel lot that is a hang with no output at all.
- **`./` is not decoration.** git returns bare names like `configure-repo.sh`; without the prefix a
  relative name is looked up in `PATH`, not in the tree, and the whole lot answers "command not
  found".

## The plugin manifest is armed before the drift can happen

Written before the plugin manifest existed, and armed on its own the day it landed — the guard was
in place before the drift could happen, which is the only order that works for a check whose whole
point is to catch a silent one. (Read with `[ -f ... ]` first, never assumed: a generated project
may ship no plugin manifest at all.)
