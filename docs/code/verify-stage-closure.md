# `checks/verify-stage-closure.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What this carries, and what it deliberately does not

The three gestures a closed stage owes are `METHODE.md`'s to state (prune the hot side, write the
archive, file the research). The first is already guarded — `verify-growth.sh` asks, when an archive
directory is born, whether the hot side shrank. This check carries ONLY what that one cannot see,
because two controls answering the same question end up disagreeing with each other before they
disagree with reality.

**The two are inverses, and that is what keeps them apart.** This one reads a closed interval
between releases and asks whether an archive was written at all; the other is triggered BY an
archive and asks whether anything was pruned. An archive with no purge is invisible here; a release
with no archive is invisible there.

## The trigger was chosen on a measurement, and the obvious one lost

"A merged pull request should be followed by a write to the tracking doc" looks compelling: 99 % of
them are, within 24 h. But against 400 instants drawn at random over the same period, 88 % are too
— an 11-point edge, and a guard that would bite on 1 pull request out of 107. At 72 h the edge is
zero. During an active session the tracking doc is written several times a day AND several pull
requests land, so the correlation comes from density, not from cause. A RELEASE is a closure; a
fix's pull request is not.

*(The method — a control group of random instants — and the full figures live in the stage's own
RECHERCHE.)*

What the release decides is the REFERENCE POINT, never the rhythm: this check runs at every commit,
like its siblings, and speaks the moment a closed interval is left empty — not only at the next
release.

## Why it is advisory, not blocking

⚠️ A verdict that depends on context is a warning, never a block. A patch release does not
necessarily close a stage, and nothing mechanical distinguishes one that does from one that does
not. Blocking on that would refuse commits over a judgement call — which is exactly how a guard
earns its own bypass.

Advisory is a claim about the EXIT CODE, not the wording: `check.sh` turns any non-zero into a KO,
which fails the gate and blocks the commit — so a script that prints `✗` and exits 1 is a blocking
check whatever its own header says. This one prints `⚠` and always exits 0.
