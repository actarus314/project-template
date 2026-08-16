# `checks/verify-echo.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What it looks for, and why TF-IDF rather than embeddings

Two paragraphs stating the same fact in different words — not a verbatim copy, which METHODE's link rule already catches. The restatement is what no diff can see: the same fact without a shared sentence.

Sentence embeddings were tried first and do not work here: a static model flagged six percent of every possible pair, and what it alone reported was noise. The reason is structural, so no tuning reaches it — every document here talks about GitHub, CI and security, and the shared domain vocabulary drowns the signal. Twelve prose linters were examined too; none compares two passages at all. What works instead is cheaper: a restatement reuses the technical vocabulary — `develop`, `staging`, `--artefact` — so it gives itself away without anything needing to understand it.

What a link POINTS AT is excluded from that vocabulary, its text kept. A target is a path, and two paragraphs each pointing at a third document scored 0.40 on that document's folder name — `respect`, `regles`, words neither author wrote, where their own prose scored 0.25. Scoring the pointer punished the very shape `METHODE.md` asks for.

## The threshold is a dial, and why it blocks anyway

Measured in both directions. A restatement reworded on purpose ("container runtime" for Docker) scored 0.32 — first against what it restated, but under the 0.40 default: below the dial, the rest stays judgement, stated outright. And of 21 pairs at 0.40, 10 were real and the lowest scored 0.40 exactly, so raising it trades 3 real findings for 2 false. What moved instead was the corpus — a skill restates the runbook by design, so that pattern left it. A warning nobody must act on is a warning nobody reads.

## What the weights are anchored to, and why it is not the working tree

A score is not a property of two paragraphs but of two paragraphs **against a corpus**, since a word's weight is how rare it is there — so a growing corpus re-judges text nobody touched. Measured: one added document turned a pair between two untouched files from 0.3989 to 0.4012, not a word changed; 42 % more corpus moves a score by 0.078, enough that a commit refused at 0.49 came back green seconds later. A check that depends on what other sessions are typing gets worked around, and one that gets worked around stops being read.

The weights therefore come from **HEAD**, while what is JUDGED stays the working tree: the anchor is the instrument, not the object. A neighbour's uncommitted writing then moves no score at all (0.0000, against a new pair under the old anchor), for one `git cat-file --batch` per repository, and no pair crossed the threshold on switching. A commit made here does move the anchor, deliberately: the complaint answered is "refused over what another session wrote", never "the weights never change". Two fallbacks stay on the tree and are worded apart — no commit at all, and nothing committed in this group — one wording for both having once had a committed repository report itself as having none.

## What is exempted, and how narrow each exemption is kept

A paragraph pointing AT the other document is the pointer METHODE prescribes, not a copy, so it is exempt — but the exemption fired on the file NAME alone, and a name worn by several files names a *kind*: "a `DETAILS.md`" bought what 6 766 pairs took, 86 % of that group's. A shared name carries its folder now, and a restatement planted across two of them scored 0.81 where the old rule reported nothing.

Tightening it surfaced 201 pairs where there had been one, and 200 were **headers** — what stands before a file's first section, which a convention gives every file of a kind alike. Those are exempt too, which is why the two ship together: apart, one is a flood and the other a hole. A header is only recognised where a first section exists, or a file without one is read as all header.

Every exemption, and every group, is printed with the verdict whatever that verdict is: an exemption nobody counts grows until it covers the corpus, a dropped empty group is indistinguishable from one never opened, and the verdict once claimed "in either repository" with no neighbour there at all.

## How the document set is built

Pairs are reached through an inverted index: two paragraphs sharing no word score zero, so they are never visited. Identical result, 2.2 s down to 0.5 s — which is why the check still compares EVERYTHING at every commit. Narrowing it to the touched files would have bought that time by moving cover to the pull request.

Detected, never listed — a hardcoded list presumes a project keeps its prose where this one does, leaving one that writes into `documentation/` or `wiki/` invisible, quietly. Every tracked `.md` is read, grouped by the project it belongs to (`repo/`, `templates/`, and `workspace/` when the neighbour exists) and compared inside a group only: `templates/` mirrors this repo's docs on purpose, so its `AGENTS.md` restating this one's is the template working.
