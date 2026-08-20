# `checks/verify-turn-claims.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What a turn CLAIMS against what it did

A `Stop` hook: two claims checked as the turn ends, against what the turn actually ran.

Nothing else watches the TURN: the thirteen other checks watch FILES and none watches what gets ASSERTED. Two failures kept coming back:
· a defect is named, and the turn ends without touching anything;
· a counted total is stated that appears in no tool output — typically relayed from a subagent;
· a table of MEASUREMENTS is rendered and nothing is written down, so the measurement dies with the conversation. The third signal exists because a measurement can be rendered and lost: timings for every check were measured, shown, and never landed in any document.

Both are COUNTED, never judged. That is deliberate: a model asked to review a turn gives a false green often enough to matter, and stacking several does not help — nine judges from seven families supply about two independent votes, and the best single judge matches the whole panel. So no model reviews anything here, and the thresholds come from measurement rather than from taste.

🔴 BLOCKING. A signal ends the turn with `decision: block`, and the reason goes back to the model, which then has to act on it or state why it does not apply. `stop_hook_active` caps that at ONE relaunch per turn: a false positive costs one extra exchange, never a loop.

That is a weaker guarantee than the other two hooks carry. Those refuse a literal string, present or absent; these three signals read prose, which is where a guard is wrong. What makes blocking affordable here is the cap above, plus the journal below: every bite is recorded WITH the signal that produced it, so the rate is read off an indicator instead of being remembered. A signal that turns out to fire too often comes back to advisory by changing `decision` on one line.

The patterns were tuned against 4463 real turns of this project's own transcripts: the obvious wordings fired on ~15 % of turns, which is unreadable. Each narrowing below is what brought them under 1 %. Anything loosened here must be re-measured the same way, not eyeballed.

Wiring: see [`verify-housekeeping.md`](verify-housekeeping.md).

## Implementation notes

What a turn CLAIMS, against what it actually ran: a defect stated with nothing edited, a total quoted that appears in no output, measurements rendered and never written.
Blocks ONCE per turn, then lets the turn end.
🔴 How each signal was dimensioned on real transcripts: docs/code/verify-turn-claims.md.

---

The journal, if it is on. A hook is the most fragile gate there is: it lives in a LOCAL settings file outside every repository, and one that stops being declared simply never fires — no error, no output, no trace. Recording the firing is the only way an indicator can tell "this gate works" from "this gate is gone", and check.sh cannot do it: it never runs the hooks.

🔴 Two properties this needs, and neither is decorative:
· ANCHORED TO THE SCRIPT, never to the working directory. A Stop hook fires wherever the session happens to sit; a relative path records only the turns played from the repo root and drops the rest in silence — the denominator of a rate, gone without a trace.
· THE VERDICT, not merely the firing. A `0` written before the analysis answers "did the gate fire", never "did it bite" — and a threshold is set on the second question.

---

What THIS turn ran, read back from the transcript: the tools invoked, and their outputs. Both come from the transcript and nowhere else — an earlier version proved which way this goes wrong.
It used `git status` as its evidence of an edit, and during a working session the tree is almost never clean, so the guard fell silent nearly always: green, and blind.

Reading stops at the previous USER message, which is where this turn began.

---

No transcript means no way to tell what the turn ran: say nothing rather than accuse.
A PARTIAL read is a different case, and it splits the signals in two. What was seen can be asserted; what was NOT seen cannot. Signal 1 accuses on an ABSENCE (nothing edited), so an unread line could hold the very edit that clears it — it stands down. Signals 2 and 3 accuse on what is PRESENT in what was read, and a missing line can only make them quieter, never wrong.

---

Signal 3 — a table of measurements rendered while nothing was written. Measuring is cheap and forgetting to record it is invisible: the numbers simply vanish with the turn. Vocabulary of measurement alone fired on 6 % of turns and a table alone on 3.75 %; requiring BOTH, with at least three numeric rows, brings it to 0.77 %. A turn that wrote nothing at all is left alone — that is a conversation, not a lost measurement.

## A French thousands separator is a space

`5 300` used to be read as the total `300` — the tail of a number, announced as if it were the whole, and every number past a thousand produced that false positive. Groups of three are now matched as one number. The separators then come off before the comparison, because tool output prints `5302` and never `5 302`: without that, a French-formatted number would be unbacked by construction.
