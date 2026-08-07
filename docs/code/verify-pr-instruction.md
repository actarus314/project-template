# `checks/verify-pr-instruction.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## It measures, it does not refuse — and that is the whole point

Whether a pull request may be opened without the maintainer saying so is settled: it may not
(`AGENTS.md`). **Whether that rule needs enforcing in code is not**, and this instrument exists to
answer that rather than assume it.

So it records and returns: it never denies a tool, and cannot wedge a session.

🔴 **The decision threshold is written down BEFORE the data**, so that no figure can be read into
whatever was already wanted: **after 20 openings, if the share opened WITHOUT an instruction is
under 5 %, the token does not get built** — the rule sufficed.

⚠️ **The old 49 % is NOT the baseline.** It was measured while this repository's RUNBOOK still
assigned "PR `develop → main` … merge" to the assistant — an explicit authorisation. Comparing the
next twenty against it compares two regimes, not two disciplines. **What decides is the absolute
rate against 5 %.**

## The gesture, never one script

`gh pr create` appears **84 times** in this repository's history. Watching only `open-pr.sh` leaves
the door beside it wide open, so both are matched, in all their forms.

🔴 **In COMMAND POSITION, never anywhere in the string** — both mistakes happened on the first live
opening: a commit message quoting `open-pr.sh` counted, and a real opening was skipped because the
line also ran a `grep`. **Substring presence is not execution.**

Wrappers are peeled **one token at a time, testing before each peel**. A single regex could not:
it either ate the target (`./open-pr.sh` looks like a path) or stopped short of it (`direnv exec
<dir>` is three tokens). Verified on six shapes, heredoc and same-line `grep` included.

## Tokenising with `shlex`, never `.split()`

The peeling rule includes `VAR=value`, so an environment prefix (`GH_TOKEN=x gh pr create …`) does
not hide the command behind it. Split on whitespace, a **quoted assignment holding the name** breaks
apart: `PKG="check.sh open-pr.sh checks"` leaves `PKG="check.sh` for that rule to peel, and promotes
`open-pr.sh checks …` to the command position — an opening recorded for a line assigning a string.

It produced **one false reading out of the first two collected**, on an instrument whose job is to
decide a percentage over twenty openings: a base half wrong decides nothing. `shlex` respects the
quotes, and falls back to a plain split where they are unbalanced, since there it raises.
⚠️ **The journal records the verdict, never the command read**, so this was diagnosable only from
the session transcript.

## Consumed, never dated

An order and the opening it authorises were measured **up to 31 turns apart**, with only 39 % in
the same turn. So any expiry short enough to restrict would refuse real orders, and any expiry long
enough to cover them would authorise everything for the rest of the session. **One order, one
opening** dissolves that: the token has no lifetime, and disappears on use.

⚠️ **Known and counted**: an order carried by its expected *result* — "une PR par repo", "promeus" —
names no opening verb, and one order can command several openings. The pattern matched **40 of 1281**
real messages; the forms it misses are listed in the research. As an instrument this only skews the
measure slightly pessimistic. It would matter if this ever became a gate.

## The prompt field is not named

The field carrying the prompt is undocumented for `UserPromptSubmit`, so **every text value** of the
payload is read instead. Naming one is what left the neighbouring check mute for seven hours.
