# `checks/verify-do-not-break.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## One script, not four

What the four targets have in common is the reason they are written down at all: breaking one of
them produces NO error. The skill vanishes from the list, a session silently loses the documents it
reasons from, a generated project silently ships without three of its files, a hook stops firing.
Nothing reports any of it, in either direction — which is precisely the shape of rule that
discipline never holds on its own.

Multiplying tools is its own failure mode, and these four are read at the same moment, for the same
question: "is anything quietly unplugged?" Two of them live outside the repository, so the CI has
nothing to look at, and one is the generator's own — absent from every project this repo generates.
Each target DETECTS whether it applies here; what is skipped is NAMED in the verdict, never folded
into a bare tick.

## The symlink: two incidents

The skill is reached through a symlink into this repository on purpose — a copy would drift, and
drifting copies of these recipes are what the anchoring in [`AGENTS.md`](../../AGENTS.md), "Do not
break", was meant to end.

**The link belongs to whichever repository HOLDS the skill.** Every other one shares the machine
with it and must not be asked to account for it: without this condition, the link pointing at the
template — which is correct — failed every generated project on the same disk.

**Every skill under `skills/` is detected, never named.** This was hard-coded to `new-project` for
as long as there was only one skill, and the second skill shipped with its link watched by nothing
— which is the exact failure mode a skill carries anyway: an unlinked skill does not error, it
simply never appears.

## The verdict names what it read

A tick listing all four targets while three were skipped is the shape of green this repo has
already been caught printing. The verdict therefore always states what it actually looked at
(`read_targets`) and what it could not (`skipped`), never a bare ✓.
