# `checks/verify-line-form.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## A sentence cut across two lines

The rule is `METHODE.md`'s — one sentence per line, no width imposed on top of it. This check arms it: a hard line break is refused unless the line above it already ends a sentence, or ends a piece of structure that could never be a sentence's tail in the first place.

## What reads as structure, never as prose

A line is left exactly as found — never treated as a candidate for joining — when it is one of: a blank line, a heading, a table row, a bullet, a horizontal rule, an HTML comment, or a fenced code block. None of these can continue the sentence above, so whatever came before it was already complete.

Quote markers (`>`) are stripped before any of those tests run, not after. A table, a bullet, a fence marker or an HTML comment opening still reads as itself one level inside a blockquote — and, because the strip happens first, a fence or a comment that OPENS inside a blockquote is also recognized as still open on every line that follows, exactly as it would be unquoted. State, not just the opening line, decides whether a line is content or prose: a bash example nested in a callout stays untouched from its opening fence to its closing one, and a multi-line HTML comment stays untouched from `<!--` to `-->`, wherever each of those lands.

## Third-party texts keep the layout they arrived with

`CODE_OF_CONDUCT.md` and every `LICENSE*` file are excluded by name, never reformatted. Rewrapping them would not change what they say, but it would turn a `diff` against the upstream original into noise for no reason — the file stops being comparable to the text it was copied from.

## Why a width threshold was rejected, not just tuned

`METHODE` once measured a real number for this: a median of 92 characters per line, across 57 files. That number was never usable as a threshold, because the corpus behind it was itself hard-wrapped — calibrating a column width from it would have re-encoded the exact defect the rule exists to remove. `verify-changelog.sh` made the identical mistake once, capping an entry at 750 characters taken from the corpus's own third quartile, before that cap was replaced by a fixed 300 chosen independently of what it was measuring.

A sentence boundary carries no such circularity: it does not shift when the file it is read from is wrong. One sentence per line is binary — a line is cut, or it is not — and a binary rule is the kind a check can actually arm, where a borrowed width never could have been.

## Tuned against a file already believed conformant

Before the exemption list covered headings, tables, bullets, quote markers, HTML comments and fenced code, the detector was run against `CHANGELOG.md` — a file already believed to respect the rule. The first version did not return 0 there. Each false hit narrowed the pattern — a bullet ending in a colon, a bold span closing a sentence, a code span closing one — until the file read clean, and only then was the same exemption list extended to the rest of what a `.md` file can hold.

A check that cries on a case already known to be legitimate gets overridden by reflex: proving it silent on conformant text first is what keeps this one armed instead of muted.
