# `checks/verify-stage-closure.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What this carries, and what it deliberately does not

The three gestures a closed stage owes are `METHODE.md`'s to state. The first is guarded — `verify-growth.sh` asks, when an archive is born, whether the hot side shrank. This carries ONLY what that one cannot see: two controls answering one question disagree with each other before they disagree with reality.

**The two are inverses, and that is what keeps them apart.** This one reads a closed interval between releases and asks whether an archive was written; the other is triggered BY an archive and asks whether anything was pruned. An archive with no purge is invisible here; a release with no archive is invisible there.

## The trigger was chosen on a measurement, and the obvious one lost

"A merged pull request should be followed by a write to the tracking doc" looks compelling: 99 % of them are, within 24 h. But against 400 instants drawn at random, 88 % are too — an 11-point edge, a guard biting on 1 pull request out of 107, and no edge at all at 72 h. In an active session the doc is written several times a day AND several pull requests land: the correlation comes from density, not cause. **A RELEASE is a closure; a fix's pull request is not.** *(Method and full figures: the stage's own RECHERCHE.)*

The release decides the REFERENCE POINT, never the rhythm: this runs at every commit, like its siblings, and speaks the moment a closed interval is left empty.

## The settled and the traps, where they have been split off

Those two files *(`METHODE.md`)* are consulted, never worked on, so nothing would notice them rotting; a closure is when they are re-read. Detected with `ls-files`: a project keeping one tracking doc hears nothing.

🔴 **A file YOUNGER than the interval is not judged**, or every closure preceding its birth reports it untouched — crying on the legitimate case is how a guard ends up disarmed. Existence is tested at the opening revision, and the ones born later are **named in the verdict**, an invisible exclusion being indistinguishable from a check that read nothing. ⚠️ It counts COMMITS: it answers *"was this touched"*, never *"was it re-judged"*.

## Why it is advisory, not blocking

⚠️ A verdict that depends on context is a warning, never a block. A patch release does not necessarily close a stage, and nothing mechanical tells one that does from one that does not. Blocking on a judgement call is exactly how a guard earns its own bypass. *(What `blocking:` claims, and why it is about the exit code: [`README.md`](README.md).)*
