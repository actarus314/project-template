# `checks/verify-dropped-comment.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## A passage that simply disappears

`verify-comment-drift.sh` asks a file to carry less comment. It says nothing about **where what
was cut ended up** — and the two are not the same question. A header trimmed to satisfy the level
can just as well have been deleted outright, taking with it the only copy of a measurement or a
pitfall.

This happened while the neighbouring check was being fixed: five facts were cut out of
`verify-checks-wiring.sh` — among them *"three checks disagreed with themselves about blocking and
nothing noticed"* — and none of them landed anywhere. Every gate stayed green, because no gate was
looking at that.

## Why a DECLARATION, and not a measurement

The obvious design measures whether the deleted text reappears in a `.md`: extract the distinctive
tokens of the removed block, look for them in the added documentation, fail below some ratio. It
was built and measured, and it does not work.

🔴 **The numbers rule it out.** Replaying the loss above, the affected blocks scored **31 %, 36 %
and 41 %** of their tokens present — while the distribution over 40 commits demanded a threshold of
**15 %** to fire on no more than 1 block in 58. A guard tuned not to be noisy would have missed the
very case that motivated it; raised to 50 %, it would have accused 22 % of all historical blocks,
most of them legitimate rewrites.

The cause is structural: a token ratio measures **rewriting**, not **loss**. Condensing a block
keeps much of its vocabulary even when the fact is gone. Measuring word presence rather than
meaning is the same defect `verify-delegation.sh` has, and it is not worth reproducing.

## What it asks instead

Two decisions, and the check only insists that one of them was made:

· **deleted outright** — the passage should never have been written there. `drop: <file>, what went
and why` in a commit message. The check reads the messages and never judges the reason: what it
refuses is the absence of a decision, not a decision it disagrees with.

🔴 **A declaration covers ONLY the files it NAMES.** The first version accepted any `drop:` anywhere
on the branch and cleared every deleted block with it — a **maximal**-scope exception hiding inside
a **minimal**-scope mechanism. It was found the day this check was written, by a sweep inventorying
every exception in the repository, on this check's **own first commit**: one declaration, nineteen
blocks passed. The verdict had not lied — it said *"19 with a note or a declaration"* — but nobody
had justified those nineteen one by one.
· **kept** — it moves into `docs/code/<name>.md`, rewritten to fit its new home if that is what it
takes. Touching that note is the whole signal.

⚠ **Neither is the default.** A comment that repeats the documentation should go and leave no
trace; a measurement should survive somewhere. Choosing per passage is the point.

## The threshold, and where it comes from

**5 lines**, measured before being chosen: over the last 40 commits, blocks of that size were
deleted 24 times — **19** alongside their own note, **5** without. So the declaration is asked for
on roughly **one commit in eight**, which is what makes it bearable as a blocking check.

Untracked files count as touched: a note written for the branch in hand is often not committed yet,
and a file git does not track appears in no diff. Leaving that out would have failed the first
honest use of the check.

## Why it judges COMMITS and not the working tree

The declaration lives in a commit message, and a `pre-commit` hook **cannot read the message of the
commit it is running for** — verified rather than assumed: `.git/COMMIT_EDITMSG` does not exist at
that moment. A check reading the working tree would therefore refuse a deletion whose `drop:` line
was written correctly, which is the worst kind of guard: one that punishes the right behaviour.

So it compares `<reference>...HEAD`. During a `pre-commit` it judges the commits already made on the
branch; the deletion being committed right now is judged at the next commit, or by the CI — which
sees the whole branch before any merge, and is the authority in any case.

## Three destinations, one known

The check recognises `docs/code/<name>.md` and nothing else, because that is the only destination it
can derive from a file name. A passage whose real owner is `repo-controls.md`, `METHODE.md` or the
standard is moved there and **named in the `drop:` line** — the declaration carries what the check
cannot infer. Deciding which document owns a fact is [`METHODE.md`](../METHODE.md)'s job, never a
script's.

