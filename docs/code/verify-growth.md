# `checks/verify-growth.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Curated documents that only grow

Scripts are NOT here: a comment outgrowing its code is another question.
Under one roof, gating the pair on prose blinded the script half on a commit touching only scripts.

The rule — a closing stage makes the tracking doc SHRINK — is [`AGENTS.md`](../../AGENTS.md)'s.
Concision is a rule of METHOD, not of published style, so it follows the method into the neighbouring workspace, where the document that must shrink lives. Archives are cold.

## Two halves, because each repository offers a different event

**`repo/` — a percentage since the last release. Weak, and kept knowing it.** The reference moves at every release, so a slow drift never accumulates: the tracking document grew **327 %** over four releases without one verdict, twice landing just under the threshold. It stays because `repo/` has no closure event to anchor to. Reading it as validated is the mistake.

**`workspace/` — the closure of a stage, and no date at all.** The first specification, *"has it shrunk once over the last N writes"*, was ruled out on the document's **263 writes**: the largest gap between two real cuts is **26**, so silence on healthy breathing needs N ≥ 27 — and at N = 27 the last cut sits inside the window. Green at every usable N, because "shrunk" cannot tell a purge from a rewording; a sliding balance is positive **79 %** of the time.

What replaced it is the event METHODE already names, and it is observable: an archive directory is born. Of the **23** filed, **18** shrink the hot side, **5** grow it.

The **directory** is the signal, never a file named inside it: one archive here closes its stage with a dated report and no `SYNTHESE.md`, which a guard keyed on that name would pass.

An **uncommitted** closure is read too, working tree against `HEAD` — the workspace has no hook, and `check.sh` feeds its uncommitted diff into the trigger set, which wakes this check.

The hot side is **every tracked `.md` outside archives/**, never a named file — METHODE makes the tracking document a role. Over the same 23 it fails on the same five as the tracking file alone, and counts a `RECHERCHE-*` moved into the archive — itself a purge.

The tag gates the `repo/` half **alone**: exiting on a missing tag would skip the other, and a first stage closes long before a first release. Bytes AND lines are compared there: at 57 to 175 bytes per line, a document can swell by half in bytes without moving a line.

Why this anchor and the neighbouring check's cannot be swapped:
[`verify-comment-drift.md`](verify-comment-drift.md). ⚠️ Settled when both halves had an anchor — this one's workspace half has none, so the pair is an input to the overlap review, not a closed case.

BLOCKING. Growth is often legitimate — a subject arrives. What it forbids is growing unnoticed, unable to say at closing time what breathed.
