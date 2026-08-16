# `checks/verify-growth.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Curated documents that only grow

Scripts are NOT here: a comment outgrowing its code is another question.
Under one roof, gating the pair on prose blinded the script half on a commit touching only scripts.

The rule — a closing stage makes the tracking doc SHRINK — is [`AGENTS.md`](../../AGENTS.md)'s, and `METHODE.md`'s discriminator is what sends it into the neighbouring workspace too. Archives are cold.

## Two halves, because each repository offers a different event

**`repo/` — a percentage since the last release. Weak, and kept knowing it.** The reference moves at every release, so a slow drift never accumulates: the tracking document grew **327 %** over four releases without one verdict, twice landing just under the threshold. It stays because `repo/` has no closure event to anchor to. Reading it as validated is the mistake.

**The percentage needs a FLOOR, because alone it is harshest on the smallest document** — which is to say most lenient where there is most to read. 25 % of a 3.6 KB note is a paragraph and a half; the same 25 % of a 30 KB one is fifteen. Measured on this repository: four blocks on small documents, none on a large one. Below 1 500 added characters the percentage therefore does not decide. The two hold **disjoint** populations — the floor governs what is under 4× itself, the percentage everything above, where it is the only thing holding them — so the floor relaxes NOTHING for a big file: on an 86 KB document the percentage demands 12 921 characters, long past the floor.

The percentage moved to **15 %** with it, and only that half of the pair tightens: it is what holds the big documents, and it now allows a third less. Neither number is a norm. The floor is the editorial *feuillet*, and the ATLF states outright that it is not a legal standard; the shape — an absolute floor that suspends a ratio under a given volume — is what has a precedent, in SonarQube's quality gates, where duplication and coverage conditions are ignored until a change reaches 20 new lines. What neither number catches: a document that grows a little at every release, since the reference moves with each one.

**`workspace/` — the closure of a stage, and no date at all.** The first specification was ruled out on measurements now filed in the stage's archive.

What replaced it is the event METHODE already names, and it is observable: an archive directory is born. Of the **23** filed, **18** shrink the hot side, **5** grow it.

The **directory** is the signal, never a file named inside it: one archive here closes its stage with a dated report and no `SYNTHESE.md`, which a guard keyed on that name would pass.

An **uncommitted** closure is read too, working tree against `HEAD` — the workspace has no hook, and `check.sh` feeds its uncommitted diff into the trigger set, which wakes this check.

The hot side is **every tracked `.md` outside archives/**, never a named file — METHODE makes the tracking document a role. Over the same 23 it fails on the same five as the tracking file alone, and counts a `RECHERCHE-*` moved into the archive — itself a purge.

The tag gates the `repo/` half **alone**: exiting on a missing tag would skip the other, and a first stage closes long before a first release. Bytes AND lines are compared there: at 57 to 175 bytes per line, a document can swell by half in bytes without moving a line.

Why this anchor and the neighbouring check's cannot be swapped: [`verify-comment-drift.md`](verify-comment-drift.md).

BLOCKING. Growth is often legitimate — a subject arrives. What it forbids is growing unnoticed, unable to say at closing time what breathed.

**A closure is a gesture, not a commit**: the archive is born in one, the hot side is pruned in the next. So the comparison cannot end at the birth, which froze "after" before the pruning existed.

🔴 **A RENAMED archive is not a born one**, and the worktree against `HEAD` reads it as one. Measured on 2026-08-12: three folders gaining a date prefix asked the hot side to shrink for stages closed a month earlier. What `--diff-filter=R` reports therefore leaves the birth set — proven both ways, an uncommitted archive still triggering and a rename alone no longer.

🔴 **Ending it at `HEAD` moved the same fault one step on**, and it bit three times before the shape was seen: the stage that opens next **legitimately** reopens work, so the hot side climbs again and a closure that did prune is reported as one that did not. The question is therefore whether the hot side **ever** dropped below its pre-closure size — walked commit by commit, stopping at the first that did. A fact, settled once and for good, where a window of N commits would have been one more threshold to defend.
