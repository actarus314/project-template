# `checks/verify-comment-drift.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Three limits, and why there are three

**Drift** — the difference between how fast the comment grows and how fast the code under it grows,
measured against the last **merged pull request**. This is the shape the rule fails in: a document's
narrative migrating into a script, one paragraph at a time.

The threshold is **40 points**, and it comes from measurement rather than taste: across this
repository's releases the difference has a **median of 0**, a **95th percentile of +6**, and exactly
one real outlier at **+149** — a script that gained 196 % comment for 47 % code. Well above the
noise, well below the one case that mattered.

**Level** (25 %) and **longest block** (6 lines) close what drift cannot see: a file **born**
verbose never grows, so drift never speaks about it. Both were measured before being set — the
figures, and the reading of every block the thresholds spare, are in the tracking doc.

🔴 **Level and block apply to TOUCHED files only.** The debt is paid where work happens. Applied to
the whole tree the day the rule landed, they would have turned all 25 scripts red at once, and a
guard that is red everywhere is a guard nobody reads.

## What the counting cannot assume

**The comment marker is looked up per language**, never assumed to be `#`. This check travels into
every generated project, and a `#`-only reading would count zero comments in a TypeScript or Go
project — reporting a tidy "nothing to see" on a file that is 80 % commentary.

**Both repositories are read** — why a method rule crosses is [`AGENTS.md`](../../AGENTS.md)'s to say.

The workspace carries neither remote nor tag, so what crosses over is the reference **timestamp** —
the same mechanism [`verify-growth.md`](verify-growth.md) uses, but **not the same instant**, since
the two anchors differ. Which is the next section.

## Why this anchor is the near one, and growth's is the far one

The two guards deliberately compare against different points, and swapping them kills both — in
opposite directions. The discriminator is what each measures.

| | `verify-comment-drift` | `verify-growth` |
|---|---|---|
| Measures | a defect a **change** introduces | a size that **accumulates** and must come back down |
| Anchor | last **merged PR** (`origin/main`) | last **release** (the tag) |
| Given the other's anchor | re-condemns merged, green work | goes permanently silent |

**Growth needs the far anchor.** `origin/main` moves at every merge, so any accumulation resets to
zero by construction: a document gaining a few percent per pull request would never once cross a
threshold, however far it drifted over twenty of them. That is structural, not a tuning question.
Measured here: the tracking doc read **+24 %** against the tag and **−0.2 %** against `origin/main`
at the same instant.

**Drift needs the near one.** Anchored on the tag, the touched-file input set on this repository
went from **1 file to 41** (23 of them scripts) — twelve already-merged pull requests, each green
when it landed, put back on trial.

🔴 **Not because "releases are rare".** That was the reason first written into the script, and it is
false in the repository the script lives in — four tags in five days. The reason that holds at any
release cadence, and therefore travels to every generated project, is the one above: never re-judge
merged work.

⚠️ **Before the first release, growth is silent** and says so. There is no closing point yet, so
there is nothing it could honestly compare against — a real gap only if a project stays untagged for
long, which is a fact to measure rather than assume.

## The bulk counting, and the trap in it

Three `git grep` calls per marker family per side, whatever the file count — not four forks per
file, which cost 152 processes for 38 files. The three counts are:

| | |
|---|---|
| `A` | non-empty lines |
| `B` | leading-comment lines |
| `C` | lines holding the marker (leading **or** trailing) |

Comments are `C`, code is `A - B`. A trailing comment counts once in each, which is exactly right.

⚠️ **The join must key on the marker family, never on argument order.** Several families produce
several files per kind, and a family with no match produces an empty one `awk` never opens.
