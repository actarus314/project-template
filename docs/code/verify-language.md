# `checks/verify-language.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## French left in published content

French left in versioned content — which is English by rule (standard §1, §15).

NOTHING looked for this. verify-tone.sh is the neighbouring check and it searches for the SECOND PERSON, never for the language: a paragraph written entirely in French, carrying none of the pronouns that check hunts, passed it without a murmur. Two words shipped into published documents that way, and no control was looking for it.

🔴 The signal is the ACCENT, and its limit is stated rather than hidden. Unaccented French — "un fichier sans accent" — goes straight through. What the accent buys is the cheap half of the problem, and measured across this repository it is the half that matters: of 90 accented lines, 65 are the two bilingual READMEs, 16 the French tracking doc the generator writes into the workspace, 8 the French patterns the checks must spell out and 1 the skill's trigger phrases.
Both real slips were accented. Claiming the LANGUAGE is covered would be the only true fault here; what is covered is accented French, and the verdict says so in those words.

⚠ repo/ ONLY — the discriminator is [`AGENTS.md`](../../AGENTS.md)'s to state.

Exceptions are DETECTED, never listed — a list of file names presumes a project keeps its bilingual pages where this one does:
· a `# … (français)` heading opens the French half of a bilingual README; everything from it to the end of that file is deliberate (standard §15);
· a heredoc redirected into `workspace/` writes the FRENCH side, by construction;
· QUOTED material is verbatim and not ours to reword — a regex that must match French prose, a trigger phrase the maintainer actually types, an error message quoted from a tool. Double quotes and backticks are stripped before the line is judged, the same reasoning that exempts licence text in verify-tone.sh;
· a line carrying the `fr-pattern` marker, which is verify-tone.sh's marker and not a second one invented here — a check that hunts French has to spell French out.
