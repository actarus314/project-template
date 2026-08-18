# `checks/verify-language.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## French left in published content

French left in versioned content — which is English by rule (standard §1, §15).

NOTHING looked for this: verify-tone.sh, the neighbouring check, hunts the SECOND PERSON and never the language, so a paragraph written entirely in French passed it without a murmur. Two words shipped that way.

🔴 The first signal is the ACCENT, and its limit is stated rather than hidden. Unaccented French PROSE — "un fichier sans accent" — goes straight through. It buys the cheap half of the problem and, measured here, the half that matters: both real slips were accented. Claiming the LANGUAGE is covered would be the only true fault; the verdict carries the count of what it skipped.

## Why unaccented prose stays uncovered, and what took its place

Measured 2026-08-17: sixty high-specificity French function words, swept across this check's own exemptions, found no translation left behind. Most hits were `chantier`, a borrowed house term; the only real French was a doc block quoting an output the template had stopped printing — staleness, not language.

A language detector was ruled out on the invariant every check here holds — no import outside the standard library ([`README.md`](README.md)). It would also decide badly here: 39 % of the corpus lines are under 40 characters, and at file scale a detector reads an English document holding three French lines as English.

🔴 The signal that followed is TYPOGRAPHIC, and that is where the French actually was: 95 decimal commas against 14 points before the conversion. A comma between digits carries no accent, and unlike prose it is binary — armed here rather than watched.

🔴 The REFERENCE decides these forms, never the corpus, and the rule itself is the standard §1's to state. What belongs here is what it cost to find out: the space before `%` and the space inside `15 739` turned out never to have been French — they are what NIST prescribes, and this repository already followed it. Only the decimal comma was, which is why converting it was owed and the other two were left alone.

That is also what lets the comma be judged whole. It was once left alone past two decimals, `6,766` and `0,078` being indistinguishable — but the thousands comma is proscribed outright, so neither is legitimate.

⚠ repo/ ONLY — the discriminator is [`AGENTS.md`](../../AGENTS.md)'s to state. The templates that stay French by rule (standard §1) keep their decimals; in a generated project that exemption is inert, not wrong — its `.envrc` is gitignored, so never in the corpus. Verified by generating one: the comma bites there, and stays silent in the bilingual README's French half.

Exceptions are DETECTED, never listed — a list of file names presumes a project keeps its bilingual pages where this one does:
· a `# … (français)` heading opens the French half of a bilingual README; everything from it to the end of that file is deliberate (standard §15);
· a heredoc redirected into `workspace/` writes the FRENCH side, by construction;
· QUOTED material is verbatim and not ours to reword — a regex matching French prose, a trigger phrase the maintainer types, an error message from a tool. Double quotes and backticks are stripped before judging, as licence text is in verify-tone.sh;
· a line carrying the `fr-pattern` marker, which is verify-tone.sh's marker and not a second one invented here — a check that hunts French has to spell French out.
