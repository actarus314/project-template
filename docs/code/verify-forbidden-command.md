# `checks/verify-forbidden-command.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why blocking is safe here, and where it stops

Each rule is refused only because its verdict is MECHANICAL — a literal string, present or absent.
`verify-delegation.sh` states the same test: no model judges anything here, so blocking is safe. A rule whose verdict depends on context is a WARNING instead, never a block — a guard wrong even one time in three teaches its own bypass, and the bypass then disarms the rules that were right.

## What earns a rule, and what does not

Nothing is added here that has never actually happened. Measured over **4489 commands** really executed across this project's **47 sessions**, `gh pr merge --admin` occurred **zero** times — a rule that never bites costs maintenance and protects nothing, while every extra rule is another chance to be wrong: of roughly **six guards** written in a single day, **three** were green and blind on first writing.

## Heredocs are stripped before matching

Not a detail: the very measurements above were shell commands *containing* these forbidden strings — inside a heredoc, feeding them to `grep` or writing them into a document. A naive match on the raw command text would have blocked the work that produced the numbers this file is sized on.

## The 4th rule that was tried, and dropped

A rule refusing a **second pull request on the same undertaking** was tried three ways, after `AGENTS.md` picked up the convention as a discipline rather than a guard:

- **BLOCK** — ruled out by measurement: the signal cannot separate a fault from a legitimate stage.
  Pull requests `#94`, `#95` and `#96` score highest and are the assumed steps of ONE undertaking, so it would have refused correct work. The overlap ratio also misleads on small diffs, and a bot batch opens six at once.
- **A MESSAGE** — ruled out by observation: it fired when `#109` was opened and changed nothing, not even a mention. A notice nobody acts on is worse than none — it looks like a guard.
- **ASK the maintainer** — ruled out by the maintainer: escalation is a last resort, never routine.
  Asking at every opening adds a decision to the person who wanted fewer of them.

Nothing viable was left, and this file's own rule is that a verdict which is neither mechanical nor affordable does not belong in it. The cost named afterwards is the full open+merge **cycle** — 48 % of pull requests carry a single commit — a grouping discipline upstream, not a gate at opening time. Fuller account: `workspace/archives/2026-08-controles-du-travail/SYNTHESE.md`.
