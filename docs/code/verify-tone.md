# `checks/verify-tone.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Second person in versioned content

Forbidden by the standard (§1) and by the `AGENTS.md` of every generated project. Until this script existed, NOTHING verified it: the rule held by discipline alone, and that is how it reached nine files, four of them templates copied into every project this repo generates.

Shared, like `verify-version.sh`: called by `./check.sh` AND by the CI, so the rule lives in ONE place. A copy of this grep inside a workflow would be a second source, and two sources drift.

⚠ `git grep` on purpose, never a filesystem walk: the rule is about what is COMMITTED. An untracked scratch file breaking it is nobody's business.

## Why `-i`, and why the exceptions keep their case

`-i` is not cosmetic: `git grep` is case-sensitive, so the capitalised forms went through untouched — the second person at the START of a sentence, which is where it lands most often. The repo held none in prose, so the guard never had the chance to give itself away; the flag found one on the first run, in a workflow template copied into every generic project.

The `-i` stops at the PRONOUNS. `ALLOW` carries line markers (`# tone-self`) and literal quotations, and matching those case-insensitively would widen the only exception mechanism this script has — a `# TONE-SELF` would exempt a line. The defect was in the pronouns; the exceptions keep their original precision.

## The exceptions, and why their count is published

Exceptions are LISTED and NARROW — never a disabled rule, so a real slip inside an exempted file is still caught (the principle the standard states for gitleaks fingerprints, §18):

· licenses — third-party verbatim text, not ours to reword;
· the RULE — the lines that STATE the rule have to spell the forbidden words out;
· contributing — the "By contributing…" clause, addressed to the contributor by design;
· a quotation — foreign documentation quoted verbatim loses its value reworded;
· tone-self — the line that has to carry the very words it hunts for;
· fr-pattern — a regex that must MATCH French prose. `grep -w` treats an accent as a word boundary, so an accented French word splits in two, and the trailing fragment can itself be one of the pronouns on this very list. The hit is an artefact of the splitting, not a second person — the same accent blindness that elsewhere makes a French sweep under-count. Marked line by line, never file-wide. *(This note deliberately avoids spelling that fragment out: the marker exempting it lives in the script, and a `.md` carrying the word would need its own exemption.)*

🔴 The markers are bound to NO file and NO line: writing `# tone-self` on a line exempts it, anywhere in the tree. That is the price of a mechanism narrow enough to mark a single line, and it cannot be removed without losing the precision above. What can be removed is its INVISIBILITY — so the verdict publishes how many lines the markers exempted, the way `verify-language.sh`
publishes its own skipped count. An exemption that has to be counted out loud is an exemption somebody can notice growing.
