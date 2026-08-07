# `checks/verify-changelog.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## A user-visible change with no CHANGELOG line

The rule is [`AGENTS.md`](../../AGENTS.md)'s. Two of its three examples are **paths**, so two thirds
of it are mechanical; the third is a judgement this check leaves alone. 🔴 It catches the case that
happened: four checks shipped, `CHANGELOG` untouched — nobody notices a missing line.

**What counts as visible is DETECTED, never listed.** This check travels into generated projects
where none of its paths exist: a hand-kept list would be a list of **absent things**, still read as a
verdict. A list of three shipped scripts sat here while ten travelled, and empty is a legitimate
answer.

**The unit compared is the BRANCH** — the merge base with the default branch. With nothing to
compare it **says so**: a run that read nothing must not look like one that found nothing.

🔴 **Three sources: committed, staged, and neither.** Committed history alone made the guard block
*the very commit carrying the line it demanded* — a guard whose own remedy is unreachable teaches the
bypass it exists to prevent. In CI the last two are empty.

⚠️ **Rejected: the branch name as a trigger.** 11 of 40 pull requests carry no CHANGELOG line and are
**right** not to. A guard firing on one in four gets overridden by reflex.

## The form — the rule is standard §16, this is why the code counts as it does

The ceiling is **300 characters**, and it was 750. ⚠️ **That 750 was the corpus's own third quartile
— a threshold taken from the corpus it means to reform endorses the drift.** Sealed versions are
judged now, not merely counted: they were only counted because the corpus did not meet the rule.

🔴 **Three ways the counting goes wrong if written naively**, each measured here:

| Trap | Cost |
|---|---|
| An entry is **any** top-level bullet, not `^- \*\*` | 10 of 195 opened on an emoji or plain text — the cap never reached them |
| The trailing reference is **not** counted | counting it fails 13 of 34 entries that respect the rule |
| Stripping it leaves its **indentation** | those 2 spaces put 5 compliant entries at 301-302 |

A cap nothing is measured against and a cap nothing exceeds print the same verdict.

**`Unreleased` is exempt from the pull-request refusal, by design**: the branch writing that line has
no pull request yet, so demanding one would refuse the very commit the rule asks for — the same trap
as above, in the other half of the check.

⚠️ **Only the countable part is gated.** That an entry opens on the effect rather than on the file
that changed is a judgement — `METHODE` holds that no script reads clarity, and a model blocking on
it is worse than nothing.

The braces in `${dup}` are load-bearing: a bare `$name` before a multi-byte dash is read as part of
the name, and under `set -u` the check dies before its own message.
