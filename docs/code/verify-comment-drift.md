# `checks/verify-comment-drift.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Three limits, and why there are three

**Drift** — the difference between how fast the comment grows and how fast the code under it grows,
measured against the last release. This is the shape the rule fails in: a document's narrative
migrating into a script, one paragraph at a time.

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

**Both repositories are read** — see [`METHODE.md`](../METHODE.md) for why a method rule crosses.

The workspace reference point is the same as [`verify-growth.md`](verify-growth.md) uses.

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
