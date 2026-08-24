# `checks/verify-memories.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The sixth place, and the one Git cannot see

Memories are the sixth place a fact can live, alongside the tracking doc, the archives, the runbook, the conventions and the code ([`AGENTS.md`](../../AGENTS.md)) — and the only one with no Git structure. No diff shows them, no CI sees them, so they rot unnoticed unless something reads them on purpose. A memory absent from the index is never recalled — it exists and does nothing — and a broken `[[link]]` is reported by nothing at all.

They live under `~/.claude/projects/<slug>/memory/`, where `<slug>` is the project's absolute path with every `/` turned into a dash — which is why this check is local-only by nature: the CI has no such filesystem path to read, and that absence is not a gap to fill.

## A path in prose, which nothing else can see

A memory carries no markdown link to a file: its pointers are literals in prose, so `verify-links` never looks at them and no diff shows one going stale. **Ten of them named archive folders by a prefix dropped weeks earlier**, and the three rules above stayed green throughout.

🔴 **What is checked is a LITERAL, never a reference.** A placeholder, a glob and a `file:line` are excluded: an ellipsis and a `<slug>` stand for something, and a rank ages on its own — resolving either would be a judgement. **Measured before arming: 21 candidates, 16 literal**, and the five excluded are exactly those three shapes.

⚠️ **The one false positive was repaired at the SOURCE, not exempted.** A memory quoted another repository's file in a lived narrative, where it read as a path into this one; naming that repository made the memory truer and the collision disappear. **A per-line exemption was not built** — this check has none, and the case that would need one was a defect in the text.

## The tick this script refuses to print for free

No-op when the folder does not exist is correct — most projects have none — but a silent no-op is not: a run that read nothing at all still needs to say so, rather than let the caller print a bare "✓ memories" over it. The check always states which case it is in.
