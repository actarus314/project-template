# `checks/verify-checksums.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What a checksum proves, and what it cannot

A matching checksum proves the `.html` was touched after the `.md` changed. Nothing more: an assembly has already passed it GREEN with 29 % of the arriving facts missing — a whole block, sources included, rendered nowhere. Full account:
`workspace/archives/2026-08-decoupage-par-sujet/SYNTHESE.md`.

## Why coverage compares tokens, not sentences

Comparing sentences does not work: these pages REINTERPRET their source, and only 42 % of the sentences survive a rewrite — that drowns the signal. So `coverage()` instead lists the `.md`'s technical tokens (whatever sits between backticks: commands, files, flags — text that cannot be reworded without becoming false) that appear nowhere in the `.html`'s rendered text.

## Why it is advisory, not blocking

A styled page renders a placeholder its own way, so a residue of two or three tokens is normal — a guard that cries on every run is a guard nobody reads. What it catches instead is the ORDER OF MAGNITUDE: 2 residual tokens read as noise, 23 read as a block that disappeared.
