# `checks/verify-growth.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Curated documents that only grow

Curated documents that only ever GROW.

Scripts are NOT here: a comment outgrowing its code is a different question, asked at a
different moment and answered from a different target, so it lives in its own check.
Keeping both under one roof produced a defect within the hour — gating the pair on prose
blinded the script half exactly on a commit that touched only scripts.

The rule itself — a closing stage makes the tracking doc SHRINK — is not this note's: see
[`AGENTS.md`](../../AGENTS.md).

Concision is a rule of METHOD, not one of published style, so it follows the method into the
neighbouring workspace — where the very document METHODE names as the one that must shrink lives.
Archives are left out on purpose: they are the cold side, and METHODE states that too many
archive files is not a problem.

An absolute size would be arbitrary: repo-controls.md is legitimately long, it absorbed four
sections. What IS observable is a document that grows and never comes back down. So the
comparison is against the last RELEASE, not against a number someone picked.

The neighbouring check anchors on the last merged pull request instead, and the two are not
interchangeable: given this one's far anchor each guard fails, in opposite directions. Measured,
and tabulated, in [`verify-comment-drift.md`](verify-comment-drift.md).

The workspace carries no tag, so what crosses over is the release TIMESTAMP: both repositories
advance on the same undertaking, and its last commit strictly before that instant is the same
reference point. Reaching for a tag that does not exist there would print "no release yet" and
pass in silence — a guard fails by passing, not by shouting.

Both bytes AND lines are compared: the curated documents run from 57 to 175 bytes per line, so a
document written one sentence per line can swell by half in bytes without moving a single line.

BLOCKING. Growth is often legitimate (a subject arrives), and this header called itself advisory
long after that stopped being true — the threshold was settled on measurement and the check was
made to block, while this line went on saying otherwise. What it makes impossible is growing
without noticing, and being unable to say, at closing time, what actually breathed.
