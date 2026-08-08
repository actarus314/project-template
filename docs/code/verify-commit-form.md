# `checks/verify-commit-form.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Two entry points, one file — and the reason is drift

The rule is `METHODE.md`'s, in *"The four places a change is written"*.
It has to be answered in two places that see different things: the `commit-msg` hook holds a message **being written**, the lot holds commits **already made**.

🔴 **Written as two files, the two would diverge, and the local one is the one nobody re-reads.**
So the hook carries no rule at all — it hands its message file over and reports what comes back. `.githooks/commit-msg` is nine lines for exactly that reason.

## What this guard does NOT govern, and it is the first thing to know

🔴 **Squash-merging discards these subjects: `open-pr.sh` is what governs the default branch, and `open-pr.md` carries the measurement.**

What is left here is **the branch**, plus a `develop → main` promotion, which merges as a merge commit and does keep its own subjects.
Read alone, this check looks like a guard on the published history. It is not, and saying so here is the only thing that stops it being believed.

## The refusals, and the one that is only half a refusal

Four are mechanical: the length, the capital, the final stop, the blank second line.
The fifth reads **only the mechanical half of the imperative** — a subject opening on an article or a pronoun is describing the change rather than commanding it. Whether the sentence actually commands stays a judgement, and the verdict says so.

**The word list is the one `verify-changelog.sh` uses, and it is written twice on purpose.**
The generator copies `checks/verify-*.sh` and nothing else, so a shared library would sit in the tree and never travel. A second copy is the cost of the file arriving whole.

## Two exemptions, both measured against a real failure mode

| Exempt | What refusing it would cost |
|---|---|
| `Merge…`, `Revert…`, `fixup!`, `squash!`, `amend!` | git writes these itself — the guard would block a merge on wording no person chose |
| any author ending in `[bot]` | 🔴 **every Renovate pull request would go red.** A guard that blocks the update bot is a guard that gets removed, and the binaries then freeze silently |

## What the branch pass structurally cannot see

**The blank second line is invisible there.** Where a body is glued to the subject, git reads the whole first paragraph *as* the subject, so `%s` returns them joined and the rule has nothing left to look at.
In practice the joined text runs past the cap and is refused for its length instead — a different reason for the same message. **The hook is where that rule is actually enforced**, which is one more thing the two entry points do not share.

**The default branch is skipped, deliberately.** Published history is not rewritten *(RUNBOOK §3)*, so judging it would only ever report what cannot be fixed — the shape that gets a check switched off.

`wc -m` counts characters under a UTF-8 locale and **bytes** under `C`, where an em dash reads as three. That way the miscount refuses early; it never passes wrongly.
