# `checks/verify-generated-green.sh` — why it is written this way

> Convention: [`README.md`](README.md).
> The rule it serves, and where the door is wired: [`AGENTS.md`](../../AGENTS.md).

## The question no other check was asking

`verify-travel.sh` already generates projects, and asks whether a **path** written here still
resolves there. That is a different question from whether the **door passes** there, and the gap
between the two is where three defects sat at once:

- 33 dead relative links, because 24 notes opened with a link to a charter that did not travel;
- `verify-private-names.sh` exiting non-zero **with no output at all**, on every generated project;
- `verify-echo.sh` reporting a pair that scores below the threshold here and above it there.

None of the three is a path. `verify-travel` was green throughout, and correctly so.

## Why the checks have to run THERE

The third defect is the one that generalises. `verify-echo` scores paragraphs with TF-IDF, and the
inverse-document-frequency term depends on the size of the corpus: a generated project holds about
200 paragraphs where this repository holds nearly 700, so the same pair of paragraphs scores 0,41
there and below the threshold here. **A threshold calibrated on this corpus does not transport.**

That is not fixable by picking a better number — the documentary composition of a generated project
differs from ours, and differs again between two generated projects. What is fixable is the pair
itself: deduplicating at the source corrects both repositories at once, which is the rule anyway.

The same reasoning covers the second defect. A check whose input is *the template shipped empty*
can only be observed where that template lands. Here, the list of private names has five real
entries; there, it has none, and `grep -v` matching no line exits 1 — under `set -euo pipefail`
that kills the script before its own message can be printed. The check was red, silent, and had
been for as long as it had existed.

## One variant, said out loud

`verify-travel` generates four combinations and pays 1,76 s for it, because a path can be written
in a file that only one toolchain ships. A **door** does not work that way: the checks are the same
24 files whatever the toolchain, and every capability only adds content for them to read. So one
generation answers the question, and the richest variant is the one that reads the most.

The variant is named in the output, and in the failure message the exact command to replay it.
A check that reports a red without saying how to reproduce it gets ignored on the second occurrence.

## A red with no ✗ line is a real case

The failure path counts the `✗` lines and, finding none, prints the tail of the log instead. This
is not defensive coding for an impossible case: it is precisely what a mutely-dying check produces,
and two of them were found on this check's first run. Reporting "born red" with an empty list would
have reproduced, one level up, the very defect being looked for.

## Why it cannot recurse

A generated project ships this check like all the others, and runs it. It exits at the
`init-project.sh` test — a project that generates nothing has nothing to check, and says so rather
than exiting mute. That test is both the subject boundary and the recursion stop.
