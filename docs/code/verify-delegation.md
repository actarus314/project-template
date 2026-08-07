# `checks/verify-delegation.sh` — why it is written this way

> Convention: [`README.md`](README.md).
> The rule and its three opt-ins, and what fires this check, are the repository's to state —
> [`AGENTS.md`](../../AGENTS.md) says where. They are deliberately NOT restated here.

## Two tools, one rule, two places to read it

`Agent` carries `prompt` and `model` as fields of the event. A **workflow** carries neither: its
subagents are `agent()` calls inside a script, and that script never goes through the `Agent` tool.
Watching one tool therefore left the rule unenforced on every workflow subagent — measured while
checking a 13-agent run: they were all on the cheap model **because each call said so by hand**,
which is a habit, not a guard.

So the script is what gets read when the tool is `Workflow`, and the three tests run against its
whole text.

## What a script-wide test can and cannot claim

Per-call attribution is not attempted. A workflow script builds prompts from variables, template
strings and loops, so tying one `agent()` call to the text of its own prompt would need a JS parser
— and a guess about which string ends up where. What is asserted instead is narrow and true: this
script names a cheap model somewhere, and mentions both opt-ins somewhere. The verdict publishes
the number of `agent()` calls it saw, so a script with fifteen calls and one `model:` line is
readable as such by whoever reads the journal.

`model` is checked as a **literal in the script**, never as an event field: unset, an `agent()` call
inherits the session model, which is the expensive one.

## A named workflow is declared, never passed off as clean

`Workflow({name: "…"})` runs a saved script whose text is not in the payload. The hook says so on
stderr and returns 0. Refusing would block a legitimate call over a file it cannot see; staying
silent would let it read as checked. This is the same shape as the neighbouring guards' `NOT read:`
lines.

## Measured in flight, both halves

`PreToolUse` does fire on `Workflow`, and the event carries the script under `script`: a probe
workflow with one bare `agent()` call was **refused**, its verdict naming the call count it had
read; a compliant one ran and returned. Bite and silence, on real launches, not on hand-built
events.

That probe also produced the reason the `meta` block is stripped: it was **described** as being
about the delegation hook, and that word alone — in a description, instructing nothing — satisfied
the re-delegation test. With `meta` out of the way, the same script reports all three gaps.

An unreadable or unexpected payload still returns 0: a guard is allowed to fail by standing aside,
never by wedging the tool.

## Why the word test is still a word test

`re.search` looks for the *presence* of "delegate" and "advisor". A prompt granting itself
permission to delegate and to call the advisor satisfies both while breaking the rule — known,
written down, and not fixed here. The French pattern was widened to `d[eéè]l[eéè]g` after `délègue`, the ordinary
conjugated form, turned out to match none of the three spellings the check listed.
