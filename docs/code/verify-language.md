# `checks/verify-language.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## French left in published content

French left in versioned content — which is English by rule (standard §1, §15).

NOTHING looked for this. verify-tone.sh is the neighbouring check and it searches for the SECOND PERSON, never for the language: a paragraph written entirely in French, carrying none of the pronouns that check hunts, passed it without a murmur. Two words shipped into published documents that way.

🔴 The first signal is the ACCENT, and its limit is stated rather than hidden. Unaccented French PROSE — "un fichier sans accent" — goes straight through. It buys the cheap half of the problem and, measured here, the half that matters: both real slips were accented. Claiming the LANGUAGE is covered would be the only true fault; the verdict carries the count of what it skipped, and says in those words what it does not cover.

## Why unaccented prose stays uncovered, and what took its place

Measured 2026-08-17, sixty high-specificity French function words swept across this check's own exemptions: no translation had been left behind. Of 39 hits, 28 were `chantier`, a borrowed house term, and the only real French was a doc block quoting an output the template had stopped printing seventeen days earlier — staleness, not language.

A language detector was ruled out on the invariant every check here holds — no import outside the standard library ([`README.md`](README.md)). It would also decide badly here: 39 % of the corpus lines are under 40 characters, and at file scale a detector reads an English document holding three French lines as English.

🔴 The SECOND signal came out of that measurement: the French left in published content is typographic. 95 decimal commas against 14 points, and the mixture was arriving with new work. A comma between digits carries no accent, no other check reads it, and unlike prose it is binary — so it is armed here rather than watched.

The lookarounds spare what is not a number: a regex quantifier `{1,3}`, a CSS `rgba(16,21,28,.06)`, an awk `substr($0,3,36)`. Three digits after the comma are a thousands separator and are NOT judged — that convention was not settled, and a guard that decides one it was never given teaches its own bypass.

⚠ repo/ ONLY — the discriminator is [`AGENTS.md`](../../AGENTS.md)'s to state. The templates that stay French by rule (standard §1) keep their decimals; in a generated project that exemption is inert, not wrong — its `.envrc` is gitignored, so never in the corpus. Verified by generating one: the comma bites in `AGENTS.md` and the changelog, silent in the bilingual README's French half.

Exceptions are DETECTED, never listed — a list of file names presumes a project keeps its bilingual pages where this one does:
· a `# … (français)` heading opens the French half of a bilingual README; everything from it to the end of that file is deliberate (standard §15);
· a heredoc redirected into `workspace/` writes the FRENCH side, by construction;
· QUOTED material is verbatim and not ours to reword — a regex that must match French prose, a trigger phrase the maintainer actually types, an error message quoted from a tool. Double quotes and backticks are stripped before the line is judged, the same reasoning that exempts licence text in verify-tone.sh;
· a line carrying the `fr-pattern` marker, which is verify-tone.sh's marker and not a second one invented here — a check that hunts French has to spell French out.
