# `checks/verify-narrative.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What it looks for

The rule is in [`METHODE.md`](../METHODE.md): a comment carries the constraint, the archive
carries the story.

🔴 THE RULE HELD BY DISCIPLINE ALONE, AND DISCIPLINE DOES NOT HOLD. The inventory recorded it
as "already respected, nothing to build" — on a snapshot taken right after a manual review pass.
That measured a rule freshly tidied, not a rule kept. Three violations appeared within hours,
in the very scripts written to enforce other rules. The same story as verify-tone.sh.

THE DISCRIMINATOR, and it comes from the one conforming case rather than from theory:

# (Full-Renovate switch, 2026-07 — see workspace/archives/2026-07-autodetection/SYNTHESE.md.)

A date is allowed IFF the same line points into `archives/`. One line, one pointer, the story
lives where stories live. Anything else with a date in a comment is the narrative itself.

Scope: every COMMENTED line of every tracked text file. Not prose — a CHANGELOG, a runbook and
an archive carry dates by design.

🔴 The comment marker is per LANGUAGE, and that is not a refinement. This check TRAVELS into
every generated project, and it used to scan `*.sh *.yml *.yaml` only: in a Python, TypeScript
or Go project it read nothing at all and reported "no dated narrative" over a repository it had
never opened. A guard that travels must not assume the language of the place it lands in.

The marker is not anchored to the start of the line either: a trailing comment carrying a date is the
same violation, and an anchored pattern walks straight past it.

## Implementation notes


METHODE holds for BOTH repos: repo/ and the neighbouring workspace/, which has its own git.
The tone rule stays repo-only (workspace/ is deliberately French, and that rule imposes English),
but a dated narrative in a comment is a METHOD rule — it applies wherever code lives.
Counted per side. "repo/ and workspace/" says which trees were INTENDED; only a count says
whether either held a file with a comment marker at all.
