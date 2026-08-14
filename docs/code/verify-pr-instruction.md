# `checks/verify-pr-instruction.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## It measures, it does not refuse

That a pull request may not be opened unasked is settled (`AGENTS.md`); **whether that needs enforcing in code is not**. This answers it: it records, and never denies a tool.

🔴 **The threshold is written BEFORE the data**, so no figure can be read into what was already wanted: **after 20 openings, under 5 % without an instruction, the token does not get built.** ⚠️ **The old 49 % is not the baseline**: it was measured while the RUNBOOK still authorised the assistant to open.

🔴 **No earlier reading is a denominator** — and **the label is what keeps generations apart**: a name no earlier line contains, where `pr opened` was a prefix of its predecessor and one grep returned both. The arithmetic of the last nine is in the research.

## The order and its target, up to three words apart

Demanding them ADJACENT missed real orders: `ouvre et merge les pr` was filed as opened WITHOUT one. Past three words, `ouvre le fichier de suivi … la PR` matches and orders nothing. 🔴 **Word boundaries matter as much**: without them `ouvrir` matched inside `couvrir` and `pr` inside `premier`.

**Widening without disqualifying INVERTS the verdict**: a ban would arm the token. Three rules answer for it, read within the verb's own clause:

| Rule | Turns away | Why it holds |
|---|---|---|
| **negation** | `arrête d'ouvrir des PR` | two real bans, plus a reproach after the fact |
| **generic target** | `la capacité d'ouvrir des PR` | `des PR` names the class; an order names the object |
| **third-party subject** | `renovate peut lancer deux pr` | a bot OPENS, it does not order |

**The acceptance set is written before the pattern it tests**, both directions; the bench prints its tally. Over 1536 human prompts it matches 110 against the old 111 — 6 real orders gained, 7 false ones dropped. It runs the script, not a copy.

⚠️ **Known and unchased**: an order carried by its *result* names no verb, so the measure stays pessimistic — which would matter as a gate.

## The event also fires on text the maintainer never typed

🔴 **A finished agent reporting back armed the token** — its report quoted the opening script in a code excerpt, and the harness injects that under this event. Measured to the second, then reproduced. The bias runs the dangerous way: **an authorisation from machine noise makes the next unordered opening read as ordered**. **21 injected entries carry the pattern, 0 of 1087 real prompts carry a tag**, recounted at source.

## The gesture, never one script

`gh pr create` appears **84 times** here: watching only `open-pr.sh` leaves the door beside it open. Both are matched in all their forms, **in command position only**: a commit message quoting it counted; a real opening was skipped for a `grep`. **Substring presence is not execution.**

**Four traps make that reading hard, and each was paid for once**: the line split comes before the token split, quotes hold at both levels, wrappers are peeled one token at a time testing before each peel, and a heredoc is CONTENT. The measurements behind each are in the research, with the nine shapes it is verified on.

🔴 **The cascade is what makes a false positive serious**: it consumes the token, so the real opening that follows is filed `WITHOUT an instruction`. Overcounting inverts the verdict rather than adding noise.

## Consumed on use, and no older than its session

An order and its opening were measured **up to 31 turns apart**, only 39 % in the same turn: any expiry in turns short enough to restrict refuses real orders, any longer one authorises the session. **One order, one opening** — gone on use. **But it does not outlive the session it was given in**, one having been found armed overnight; the token carries that session, and where the field is absent the check says so rather than assume.

🔴 **A REFUSED opening consumes the order all the same** — measured three times, 21 s to 55 s apart, so the retry that followed was filed as unauthorised. Two openings repeating the same command WHOLE — peeled, it loses the repository and two targets read alike — with no order between them cannot be two pull requests: the second is a **retry**, labelled apart and outside the denominator.

**The field carrying the prompt is undocumented**, so every text value is read instead: naming one left a neighbouring check mute for seven hours. ⚠️ **No literal apostrophe in the embedded Python** — `\x27`, `shellcheck` refusing `’`.
