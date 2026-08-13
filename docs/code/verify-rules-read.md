# `checks/verify-rules-read.sh` — why it is written this way

> Convention: [`README.md`](README.md).
> The rule it serves: [`AGENTS.md`](../../AGENTS.md).

## The refusal carries the rule, not a reading list

The rule documents are named in a file the assistant receives on **every turn**. They are therefore always visible — and that is the problem: a sentence saying *read the method* arrives as **information**, exactly like a sentence stating what the method contains. Seen forty times, *read this* never becomes *this was read*.

The first answer to that was to demand the read and refuse until it happened. It was the wrong lever, on two counts that are measured rather than argued.

**Ordering a read buys nothing that is observable.** What peer-reviewed work measures is the opposite move: re-stating the rule after a lapse restores compliance for about thirty tokens, where demanding a re-read of the documents carrying it costs several hundred times that — and produces no recorded change in behaviour.

**And the gesture being demanded had gone hollow.** This check reads the tool CALL, never its result — so a `Read` the harness itself rejects still counts as one. A guard satisfiable by an empty gesture is no longer guarding.

So the refusal still fires, and the block is unchanged: the write does not happen. What travels back is the rule itself, in a few lines, at the moment it applies.

## Two tiers, and only one of them can be summarised

The method and the standard are owed by **every write**. They state how a thing is written and where it goes — and that fits in a sentence, so the sentence is what goes out.

The runbook is a different kind of document. It holds **gestures**, with their order, their URLs, their exact values and who performs each. **No short form stands in for data**: a summary of a runbook is a gesture performed from memory with a quotation attached. That tier therefore keeps demanding the read, and keeps refusing until it happens.

The split shows in where each marker is written. The rule tier marks itself **on the refusal** — once the rule has been sent, there is no read left to observe. The gesture tier marks itself **on the read**, and never on a refusal, so it stays unsatisfied until the document is actually opened.

Each tier carries its own marker, so satisfying one never satisfies the other.

## The channel: plain text on stderr, exit 2, and never JSON

Three fields with neighbouring names address different readers, and picking the wrong one fails silently.

`systemMessage` is a warning **shown to the user** — it does not reach the model. `additionalContext` reaches the model but arrives *alongside the tool result*, which is after the gesture it was meant to govern. On `exit 2`, the **stderr** message becomes the denial reason the model reads.

This check writes plain text on stderr and exits 2. Measured on the version this replaced: its JSON went to stderr while a hook's JSON is only ever parsed from **stdout** — stdout was empty, so the decision field was never honoured, the block came from the exit code alone, and what reached the model was the raw JSON with its punctuation escaped. It worked, and not for the stated reason.

**Never print JSON here.** Making this hook "correct" by moving its JSON to stdout would silence the message while the block kept working — a failure that passes rather than shouts.

## Testing it requires an isolated state directory, and that is not tidiness

The check dates its state from the reads it finds in the transcript. Run against the real state directory, a test arms it from **the session's own opening reads** — and it then refuses writes for the rest of that session, with no way back short of re-reading the documents.

`XDG_STATE_HOME=$(mktemp -d)` is therefore the condition for testing it at all. Both directions are observable there and neither is observable in place: the refusal that carries the rule then falls silent on the next call, and the gesture tier that refuses twice in a row then falls silent once the read appears in the transcript.

## Why the transcript is still read

Whoever has already read the documents is left alone. The transcript records tool calls as they were actually issued — no judgement, no self-report. Without that lookup the rule tier would interrupt a session that owes nothing.

A `Read` carrying `offset` or `limit` does **not** count, and a large document read in two consecutive halves is refused with it. That is stricter than what a human would call reading, and deliberate: any rule admitting "enough of it" needs a threshold, and the number of lines read says nothing about which ones.

## Detected, never listed

The documents are named in the script and nowhere else, this check detecting its own perimeter as every check here does. Their names are **not** written as paths in this note on purpose: it travels into projects that hold none of them, where a path would be a dead pointer.

`AGENTS.md` is deliberately not on the list: it is imported into context on every turn, so demanding a read of it would be theatre.

## What none of this establishes

That the rule now travels does **not** mean it is obeyed. Nothing here measures that, and a guard whose message arrived and went unheeded has already been observed elsewhere in this repository. What changed and is certain is the cost, and the honesty of what the refusal asks for.
