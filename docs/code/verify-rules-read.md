# `checks/verify-rules-read.sh` — why it is written this way

> Convention: [`README.md`](README.md).
> The rule it serves: [`AGENTS.md`](../../AGENTS.md).

## An injected instruction is indistinguishable from a fact

The rule documents are named in a file the assistant receives on **every turn**. They are therefore
always visible — and that is precisely the problem: a sentence saying *read METHODE* arrives as
**information**, exactly like a sentence stating what METHODE contains. Nothing separates the two,
and nothing records that the reading ever happened. Seen forty times, *read this* never becomes
*this was read*.

**Compaction turns that into a trap rather than an omission.** The summary carries the documents'
**conclusions** — the decisions, the measured facts, the rules in their short form. That is the
exact sensation of having read them, produced without a single read. Which is why `SessionStart`
re-arms this check on **every** source, compaction included: the state is wiped, and the documents
have to be opened again.

## Why the transcript, and not a marker the assistant sets

A guard the guarded party can satisfy by declaring itself satisfied is not a guard. The session
transcript records tool calls as they were actually issued, so `Read` on a given path either appears
in it or does not. No judgement, no self-report — the same discipline as every other hook here.

## A passage is not a document

A `Read` carrying `offset` or `limit` does **not** count. Taking twenty lines out of a runbook is
how a rule gets applied from memory with a quotation attached to it, and the failure this check
exists to stop is exactly that: acting on the conclusions rather than on the text.

⚠️ **This is the one place where the check is stricter than what a human would call reading.** A
large document read in two consecutive halves is refused. That is deliberate: any rule admitting
"enough of it" needs a threshold, and a threshold on how much of a document was read is not
measurable — the number of lines says nothing about which ones.

## Detected, never listed

The documents are found by looking for them under `docs/` — the method, the standard, the runbook,
named in the script and nowhere else. A repository holding none — every generated project — is not
made to read what it does not have, and the check stands down. This is the rule every check here
follows: **it detects its own perimeter where it lands**.

⚠️ Their names are **not written as paths in this note**, on purpose: the note travels into projects
that hold none of them, where a path would be a dead pointer. The one place they appear as paths is
the script, on the line that tests for their existence.

`AGENTS.md` is deliberately **not** on the list: it is imported into context on every turn, so
demanding a read of it would be theatre.

## Three ways it deliberately does nothing

- **No `SessionStart` seen** — the hook is half-wired, and a half-wired guard must not block work.
- **The target is outside the repository** — a scratch file is nobody's business.
- **No transcript in the payload** — it says nothing rather than guessing.

Once satisfied, it writes an `.ok` marker and returns immediately, so the transcript is read **once**
per session and not on every write.
