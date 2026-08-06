# `checks/verify-echo.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What it looks for

Two paragraphs stating the same fact in different words — not a verbatim copy, which METHODE's
link rule already catches (measured across the living documents: two lines, both commands quoted
where they run). The restatement is what no diff or copy-paste detector can see: two passages
carrying the same fact without sharing a sentence.

## Why TF-IDF, not embeddings

Sentence embeddings were tried first, and do not work here. A static embedding model run over
this corpus flagged 1840 pairs against this file's 45 — six percent of every possible pair — and
the pairs it alone reported were noise ("consequences not to miss" matched against "gitleaks on
every ref", at 0.94). The reason is structural: every document here talks about GitHub, CI and
security, so the shared domain vocabulary drowns the signal. Twelve prose linters were examined
too; none compares two passages at all — their "redundancy" is a pleonasm inside one phrase.

What works instead is cheaper: weigh each word by how rare it is across the corpus, and compare
paragraphs on that. A restatement reuses the technical vocabulary — `develop`, `staging`,
`--artefact` — so it gives itself away without anything needing to understand it.

## The threshold is a dial, not a verdict

Measured, not guessed: a restatement that changes vocabulary on purpose ("container runtime" for
Docker) was planted and scored 0.32 — ranked first against the paragraph it restated, but below
the 0.40 default. 0.40 reports 20 pairs on this corpus; 0.30 reports 45 and catches that reworded
case. Lowering the dial is the only way to see a deliberately reworded restatement — the rest
stays judgement, which METHODE says outright.

## Why blocking

The noise was measured before flipping it: of the 21 pairs reported at the time, 10 were real
restatements, 2 were shared vocabulary and 9 were legitimate. The lowest real one scored 0.40 —
exactly the default — so raising the dial trades 3 real findings for 2 false ones, and the dial
stayed put. What was removed instead was structural: a skill is walked step by step while acting,
so it restates the runbook by design and cites it each time — that pattern was excluded from the
corpus rather than the threshold moved. A warning nobody must act on is a warning nobody reads.

## How the document set is built

Detected, never listed. This used to read `docs/*.md` plus three names at the root, which
presumes a project keeps its prose exactly where this one does — a project writing into
`documentation/`, `guide/` or `wiki/` was invisible to it, entirely and quietly. What is read now
is every tracked `.md`, grouped by the project it belongs to (`repo/`, `templates/`, and
`workspace/` when the neighbour exists) and compared inside a group only — `templates/` mirrors
this repo's own docs on purpose, so its `AGENTS.md` restating this repo's is the template working,
not a defect, and a cross-group pair would share no vocabulary anyway.

An empty group is kept, and reported, on purpose: dropping it here is what made a silent group
indistinguishable from a group that was never read — with pairs found elsewhere, `workspace/`
would simply not appear, and nothing would say whether it had come back clean or had never been
opened. The same reasoning holds for the final verdict: it used to claim "in either repository"
whether the neighbour was there or not, so an absent `workspace/` read exactly like a `workspace/`
with nothing wrong in it. Both are printed unconditionally now, whatever the verdict.
