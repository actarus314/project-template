# `checks/verify-secret-blindspots.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What it looks for

Two places a secret can sit where gitleaks does not look, read at the same moment for the same
question: gitleaks scans the CONTENT of files git knows about, and misses both for that same
structural reason.

**A file named like a secret, tracked.** gitleaks looks for secret-shaped strings inside files,
never for a file called `.env` or `secrets.md`. An empty `.env`, a `secrets.md` holding only
headings, an `.envrc` before the token is pasted in — all pass gitleaks, get committed, and are
then filled in. The leak happens at the NEXT commit, on a path nobody watches any more.

**A token pasted into the remote URL.** `.git/config` is never tracked, so gitleaks never reads
it — not on staged files, not over the full history. A `https://<token>@github.com/...` remote
therefore sits in plain text where nothing in this repository looks, and it survives every clone
of the working copy. The credential helper is read with it: it must name a variable, never carry
a literal.

## What is published with the verdict

Which repositories were actually read, alongside the finding: the message used to claim "in
either repo" whether the neighbour was there or not, so an absent `workspace/` read exactly like
a `workspace/` with nothing wrong in it.

## Why the offending value is never printed

A remote URL carrying credentials, or a credential helper carrying a literal, is reported by
naming the remote and the setting — never the value. Repeating a leak to report it moves it into
a terminal, a log and a CI transcript, which is one more place it would then have to be scrubbed
from.

## Why the example remote is capitals, not angle brackets

`https://github.com/OWNER/REPO.git`, in capitals, never in angle brackets: this file travels into every
generated project, where the generator scans what it just wrote for placeholders it failed to
substitute. An angle-bracketed owner and repo inside a message is indistinguishable from one of
those, and would read to whoever generated the project as a template bug.
