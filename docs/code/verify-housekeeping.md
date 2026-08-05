# `checks/verify-housekeeping.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The development admin falling behind the work

blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
The development admin falling behind the work: commits piling up with nothing written down.

THREE events, because there are three ways the pass gets missed. `Stop` catches the drift, turn
after turn. `PreCompact` catches the cliff: compaction drops the conversation, and everything
decided in it that was never written down goes with it. The pass is worth asking for again there
even when the turn-by-turn guard has already asked and been answered — which is why the "asked
once" latch below does not apply to it.

🔴 `UserPromptSubmit` catches the third, and it exists because of a measured failure: the skill
this routes to lists "je vais clear" among its own triggers, the maintainer wrote exactly that,
and THE SKILL DID NOT FIRE. A skill is invoked by a model's judgement, never by a mechanism, and
nothing arms that judgement the way `verify-do-not-break` arms a hook's wiring. Here the routing
becomes mechanical: the event fires before the prompt is processed, carries `user_input`, and its
stdout is one of the three whose stdout Claude actually SEES — so the instruction reaches the
model rather than hoping the model reaches for it.

It does NOT block: injecting the reminder is enough, and refusing a maintainer's prompt over a
regex would be the guard earning its own bypass. The patterns are the strict ones measured across
1756 real human messages — 16 matches, 0,9 %, the same order as the end-of-turn signals. Loose
wordings ("en ordre", a bare "clear") matched 82 times, most of them nothing to do with the pass.

⚠ WIDENED once, on a SECOND lived miss: "est-ce que tout est clean pour un clear ?" matched none of
them — the mechanism worked, its list was short. Three candidates were measured over 1683 messages
before picking one: "(pour|avant) [un|le|de] clear" → 2 new matches, ZERO false positives (kept);
a clean/propre variant → the same 2 but narrower; and the bare word "clear" → 41 new matches,
nearly all noise (skill loads, session summaries), which is the original 82 all over again.
🔴 It stops there. "Affiche l'état du suivi" does NOT match, and must not: asking to SEE the state
is not asking for the pass, and widening far enough to catch it rebuilds the false positives.

⚠ On PreCompact it blocks ONLY when compaction was asked for by hand. An `auto` compaction means
the context window is full and Claude Code has to reclaim it; refusing that leaves the session
with nowhere to go. A guard that can wedge the tool it protects is worse than the drift it
watches, so `auto` gets the message and lets compaction through.

This is the one thing no file-watching check can see. verify-growth.sh knows the tracking doc only
ever grows; verify-stage-closure.sh knows a release left no archive. Neither knows that eleven
commits have landed since anyone last wrote a line about what they were for.

🔴 IT DOES NOT DO THE PASS — it asks for it. What it measures is COUNTABLE (commits since the last
write); what the pass itself requires is JUDGEMENT (does the tracking doc still reflect the work,
is this stage closed, what should be pruned), and no counter settles that. So the verdict routes
to the `housekeeping` skill, which carries the checklist and the writing. Code for what counts,
a model only for what is judged.

⚠ THE THRESHOLD IS MEASURED, not chosen — and it was measured TWICE, because the first reading
used the wrong denominator. Counting how often a guard would actually SPEAK (once per crossing,
not once per turn: between two commits the count does not move) across 21 days, 157 commits and
166 writes to the tracking doc:
S=4 → 11 times   S=5 → 4   S=6 → 3   S=7 → 3   S=8 → 3   S=10 → 2   S=12 → never
On that average, S=4 spoke every 2,1 days against a pass asked for by hand every 2,3 — apparently
ideal. It was not: a 21-day average flattens the sessions where the work is dense, and on the one
day this guard shipped, S=4 would have spoken FIVE times. Unusable, and the maintainer said so
before any measurement did.

S=6 is the LOWEST threshold at minimum noise: the count bottoms out at 3 from S=6 onward, so 8 or
10 buy no quiet and only arrive later. The 90th percentile of observed backlogs is 4, which puts 6
past ordinary drift and inside the real episodes. Moving it has to be re-measured the same way —
on a dense day as well as on the average, since that is the difference the first reading missed.

Other things worth saying — work left uncommitted, a branch never pushed — are REPORTED when the
guard speaks, and never trigger it. Uncommitted work mid-session is the normal state of a working
tree, and a guard firing on the normal state is one that gets bypassed within a day.

## The sequencer — a step that skips itself, and nothing sees it

Asking for the pass is not the same as the pass happening. **A skill is text**: a step gets skipped
and there is no mechanism to notice. Lived on 2026-08-05 — the line-by-line enumeration skipped, 5
facts re-measured out of 40, and a result that would have passed any "the file is not empty" check.

So the turn does not end while a pass is under way and its artefact does not yet **cover** the
tracking doc.

**Coverage, never presence.** Every backlog item number and every `##` section title is read **from
the tracking doc itself** — the total is never a figure someone picked — and each must appear in the
artefact with a verdict from a **closed set** (`open` / `closed` / `unchanged`). A closed set is what
makes this mechanical: naming an entry without a verdict does not count it, and free prose could not
be told apart from a list. That is the first of the four invariants taken from prior art: **the
verdict lives IN the artefact**, not its existence — "the file is not empty" is the same shape of
claim as the checksum that once hid 29 % of missing facts.

**Armed by all three routes.** The pass is reached by drift, by compaction, and by being asked for
in words; arming on the last one alone would leave the most frequent path sequenced by nothing.
The fourth route — the model invoking the skill on its own reading — stays outside the mechanism.
That is a limit, not an oversight: nothing arms a model's judgement.

**Disarmed by a WRITE to the tracking doc**, never by the turn ending. Falling back on the drift
threshold would disarm a pass asked for on a day with no drift at all — which is most of them.

🔴 **The 3-cycle ceiling is ours to write.** `Stop` has NO native loop protection: a hook that always
returns `block` never lets Claude stop. So the count is kept in the state directory, and on the third
send-back the turn is **released** — with what is still uncovered published, not swallowed. A guard
that can wedge the session is worse than the gap it watches, and the same reasoning already governs
`auto` compaction above.

⚠ **The artefact is scratch.** It lives in the state directory, outside both repositories, and is
deleted when the doc is written. It is deliberately not a file beside the tracking doc: a second
resume document is a second source, and the stale one is always the one that gets read.

### Three invariants deliberately NOT implemented

Prior art (`harness-engineering-skills`, `statewright`) carries four invariants. One is in. The other
three all require **fresh subagents** — an evaluator session that cannot be reused between cycles, a
fresh agent per checkpoint so the judge is not also the producer, and tools restricted per phase.
They are not oversights and they are not refused: the maintainer's own arbitration was **the closing
pass first, see whether it works, extend afterwards**. Extending is where they belong, and the
question to settle then is whether a judge that costs an agent per cycle buys more than a coverage
count that costs nothing.

Wiring (the settings file is local, never versioned — see https://github.com/actarus314/project-template/blob/main/docs/claude-code-setup.md):
"hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "<abs>/verify-housekeeping.sh" } ] } ] }
