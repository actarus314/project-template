# `checks/verify-memories.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The sixth place, and the one Git cannot see

Memories are the sixth place a fact can live, alongside the tracking doc, the archives, the
runbook, the conventions and the code ([`AGENTS.md`](../../AGENTS.md)) — and the only one with no
Git structure. No diff shows them, no CI sees them, so they rot unnoticed unless something reads
them on purpose. A memory absent from the index is never recalled — it exists and does nothing —
and a broken `[[link]]` is reported by nothing at all.

They live under `~/.claude/projects/<slug>/memory/`, where `<slug>` is the project's absolute path
with every `/` turned into a dash — which is why this check is local-only by nature: the CI has no
such filesystem path to read, and that absence is not a gap to fill.

## The tick this script refuses to print for free

No-op when the folder does not exist is correct — most projects have none — but a silent no-op is
not: a run that read nothing at all still needs to say so, rather than let the caller print a bare
"✓ memories" over it. The check always states which case it is in.
