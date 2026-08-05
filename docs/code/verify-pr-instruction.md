# `checks/verify-pr-instruction.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## It measures, it does not refuse — and that is the whole point

Whether a pull request may be opened without the maintainer saying so is settled: it may not
(`AGENTS.md`). **Whether that rule needs enforcing in code is not settled**, and this instrument
exists to answer it rather than to assume it.

So it records and returns. It never denies a tool, and it cannot wedge a session.

🔴 **The decision threshold is written down BEFORE the data**, so that no figure can be read into
whatever was already wanted: **after 20 openings, if the share opened WITHOUT an instruction is
under 5 %, the token does not get built** — the rule sufficed.

⚠️ **The old 49 % is NOT the baseline.** It was measured while this repository's own RUNBOOK still assigned
"PR `develop → main` … merge" to the assistant — an explicit authorisation. Comparing the next twenty
against it compares two regimes, not two disciplines. **The figure that decides is the absolute
rate against 5 %.**

## The gesture, never one script

`gh pr create` appears **84 times** in this repository's own history. A guard watching only
`open-pr.sh` leaves the door beside it wide open, so both are matched, in all their forms.

Commands that merely *mention* either (a `grep`, a `shellcheck`) are excluded: naming a thing is
not doing it.

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
