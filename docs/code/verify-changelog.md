# `checks/verify-changelog.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## A user-visible change with no CHANGELOG line

The rule is [`AGENTS.md`](../../AGENTS.md)'s: two of its three examples are **paths**, so two thirds are mechanical. 🔴 It catches what happened: four checks shipped, `CHANGELOG` untouched.

**What counts as visible is DETECTED, never listed.** This check travels into generated projects where none of its paths exist: a hand-kept list would list **absent things**, still read as a verdict.

**The unit compared is the BRANCH**, the merge base with the default branch. With nothing to compare it **says so**: a run that read nothing must not look green.

🔴 **Three sources: committed, staged, and neither.** Committed history alone made the guard block *the very commit carrying the line it demanded* — a guard whose remedy is unreachable teaches the bypass it prevents.

⚠️ **Rejected: the branch name as a trigger.** 11 of 40 pull requests carry no CHANGELOG line and are **right** not to.

## The form — the rule is standard §16, this is why the code counts as it does

The ceiling is **300 characters**, once 750. ⚠️ **That 750 was the corpus's own third quartile: a threshold taken from what it must reform endorses the drift.** Sealed versions are judged now, not merely counted.

🔴 **Three ways the counting goes wrong if written naively**, each measured here:

| Trap | Cost |
|---|---|
| An entry is **any** bullet, not `^- \*\*` | 10 of 195 opened on an emoji or plain text |
| The reference is **not** counted | counting it fails 13 of 34 compliant entries |
| Stripping it leaves its **indentation** | those 2 spaces put 5 compliant entries at 301 |

**`Unreleased` is exempt from the pull-request refusal, by design**: the branch writing that line has no pull request yet, so demanding one would refuse the very commit the rule asks for.

## What is ARMED, and what is left to judgement

Six faulty entries were injected; **four are refused**: an opening that is not a present-tense verb, an opening on a code span, a reference whose label and URL disagree, and a sealed entry citing a pull request newer than any merged. **Two get through and stay that way**: the section it belongs to, and whether it is TRUE.

🔴 **The section was measured as armable and it is NOT.** Mapping the opening verb to a section misreads it: the verb names the action the software performs, not the nature of the change. *"Delete a dead local branch…"* sits under **Added**, correctly. The rule would refuse 4 legitimate entries of 40, and a check crying on the legitimate is overridden by reflex.

⚠️ **Truth is unreachable**: a well-formed entry announcing a feature that does not exist passes every refusal.

The braces in `${dup}` are load-bearing: a bare `$name` before a multi-byte dash is read as part of the name, and under `set -u` the check dies before its message.
