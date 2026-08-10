# `checks/verify-pr-instruction.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## It measures, it does not refuse — and that is the whole point

Whether a pull request may be opened without the maintainer saying so is settled: it may not (`AGENTS.md`). **Whether that rule needs enforcing in code is not**, and this instrument answers that rather than assume it. So it records and returns: it never denies a tool.

🔴 **The decision threshold is written down BEFORE the data**, so that no figure can be read into whatever was already wanted: **after 20 openings, if the share opened WITHOUT an instruction is under 5 %, the token does not get built** — the rule sufficed.

⚠️ **The old 49 % is NOT the baseline** — measured while this repository's RUNBOOK still assigned "PR `develop → main` … merge" to the assistant, an explicit authorisation. **What decides is the absolute rate against 5 %.**

⚠️ **Nothing recorded before the newline fix counts either**: those readings span three generations of this code, and a broken instrument yields no denominator. **The count starts over**, the earlier lines keeping a name of their own so no later total sweeps them up.

## The gesture, never one script

`gh pr create` appears **84 times** here. Watching only `open-pr.sh` leaves the door beside it wide open, so both are matched, in all their forms.

🔴 **In COMMAND POSITION, never anywhere in the string.** Both mistakes happened on the first live opening: a commit message quoting `open-pr.sh` counted, a real opening was skipped for a same-line `grep`. **Substring presence is not execution.**

## A newline ends a command, and shlex does not say so

**The line split comes FIRST.** `shlex` treats a newline as whitespace and never emits one as a token, so a `"\n"` among the operators is read by nobody and a multi-line command collapses into one segment — whose head is then an ordinary word, `git` or `printf`, where the peel stops.

🔴 **It failed by PASSING.** Replayed over a three-day window against the pull requests GitHub recorded: **8 openings seen of 13**, the five missed all multi-line, which is the shape most commands take here. After the split: **12 of 13**.

## Quotes hold at BOTH levels, and a heredoc is content

Two splits happen — command into segments, segment into tokens — and **neither may ignore quotes**.
An operator inside a quoted argument ends the segment, and what follows lands in command position:
a JSON payload holding `cd /repo && ./open-pr.sh` read as an opening. On whitespace, a quoted assignment falls apart the same way — `PKG="check.sh open-pr.sh"` left `PKG="check.sh` for the `VAR=value` peel, which exists so an environment prefix cannot hide its command. `shlex` does both.
Wrappers are then peeled **one token at a time, testing before each peel** — a single regex either ate the target (`./open-pr.sh` looks like a path) or stopped short (`direnv exec <dir>` is three).

**A heredoc is CONTENT, never commands this shell runs** — and what quotes the gesture most is this check's own documentation: editing this note was recorded as an opening.

🔴 **The cascade is what makes it serious.** A false positive **consumes the token**, so the real opening that follows is filed `WITHOUT an instruction`. Three readings in one afternoon, **one a real opening recorded as unauthorised**: overcounting does not add noise, it inverts the verdict.
Verified on nine shapes, the two multi-line ones added once they were measured. ⚠️ **No literal apostrophe in the embedded Python**: use `\x27`.

## Consumed, never dated

An order and the opening it authorises were measured **up to 31 turns apart**, with only 39 % in the same turn. So any expiry short enough to restrict would refuse real orders, and any expiry long enough to cover them would authorise everything for the rest of the session. **One order, one opening** dissolves that: the token has no lifetime, and disappears on use.

⚠️ **Known and counted**: an order carried by its expected *result* — "une PR par repo", "promeus" — names no opening verb, and one order can command several openings.
The pattern matched **40 of 1281** real messages, and the forms it misses are listed in the research. As an instrument this only skews the measure pessimistic; it would matter if this became a gate.

## The prompt field is not named

The field carrying the prompt is undocumented for `UserPromptSubmit`, so **every text value** of the payload is read instead. Naming one is what left the neighbouring check mute for seven hours.
