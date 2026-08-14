# `checks/verify-pr-instruction.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## It measures, it does not refuse

That a pull request may not be opened unasked is settled (`AGENTS.md`); **whether the rule needs enforcing in code is not**. This answers that: it records, and never denies a tool.

🔴 **The threshold is written BEFORE the data**, so no figure can be read into what was already wanted: **after 20 openings, under 5 % without an instruction, the token does not get built.** ⚠️ **The old 49 % is not the baseline**: it was measured while the RUNBOOK still authorised the assistant to open.

🔴 **No earlier reading is a denominator either**, four broken instruments preceding this one — and **the label is what settles it**: `pr opened` was a strict PREFIX of the generation before, so one grep returned both and the count read 5 or 19. A generation takes a name no earlier line contains; the arithmetic of the last nine readings is in the research.

## The order and its target, up to three words apart

Demanding them ADJACENT missed real orders — `ouvre et merge les pr` was filed as opened WITHOUT an instruction. Past three words, `ouvre le fichier de suivi … la PR` matches and orders nothing. 🔴 **Word boundaries matter as much**: without them `ouvrir` matched inside `couvrir` and `pr` inside `premier`.

**Widening without disqualifying INVERTS the verdict**: a ban would arm the token, worse than the false negative fixed. Three rules answer for it, read within the verb's own clause, punctuation ending their reach:

| Rule | Turns away | Why it holds |
|---|---|---|
| **negation** | `arrête d'ouvrir des PR` | two real bans, plus a reproach after the fact |
| **generic target** | `la capacité d'ouvrir des PR` | `des PR` names the class; an order names the object |
| **third-party subject** | `renovate peut lancer deux pr` | a bot OPENS, it does not order |

**The acceptance set is written before the pattern and holds both ways**: 28 cases, 11 arming and 17 not, all but four real. Over 1702 human prompts it matches 116 against the old 120 — 4 real orders gained, 10 false ones dropped. The bench is with the research.

⚠️ **Known and unchased**: an order carried by its *result* — `une PR par repo` — names no verb, and one order can command several openings. That skews the measure pessimistic; as a gate it would matter.

## The event also fires on text the maintainer never typed

🔴 **A finished agent reporting back armed the token** — its report quoted the opening script in a code excerpt, and the harness injects that under this event. Measured to the second, then reproduced. The bias runs the dangerous way: **an authorisation from machine noise makes the next unordered opening read as ordered**. **21 injected entries carry the pattern, 0 of 1231 real prompts carry a tag.**

## The gesture, never one script

`gh pr create` appears **84 times** here, so watching only `open-pr.sh` leaves the door beside it open. Both are matched in all their forms, **in command position only**: a commit message quoting it counted; a real opening was skipped for a same-line `grep`. **Substring presence is not execution.**

**Four traps make that reading hard, and each was paid for once**: the line split comes before the token split, quotes hold at both levels, wrappers are peeled one token at a time testing before each peel, and a heredoc is CONTENT. The measurements behind each — including the five multi-line openings missed of thirteen — are in the research, with the nine shapes the detector is verified on.

🔴 **The cascade is what makes a false positive serious**: it consumes the token, so the real opening that follows is filed `WITHOUT an instruction`. Overcounting inverts the verdict rather than adding noise.

## Consumed, never dated

An order and its opening were measured **up to 31 turns apart**, only 39 % in the same turn: any expiry short enough to restrict refuses real orders, any longer one authorises the session. **One order, one opening** — no lifetime, gone on use.

🔴 **STILL OPEN, and the last thing between this instrument and a readable rate**: an opening REFUSED by the script consumes the order anyway, so the retry is filed as unauthorised. Measured three times, 21 s, 30 s and 55 s apart — the mechanism, not an accident.

**The field carrying the prompt is undocumented**, so every text value is read instead: naming one left the neighbouring check mute for seven hours. ⚠️ **No literal apostrophe in the embedded Python** — `\x27`, and `’`, which `shellcheck` refuses.
