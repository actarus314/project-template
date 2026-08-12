# `hooks/check-template-version.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What it compares, and the limit that comes with it

It compares the project's origin stamp to the **latest published release** of the template, never to `main`.
A change merged an hour ago is therefore invisible to it, and that is the intended reach: the stamp says which version the project was generated from, so a release is the only thing it can be ordered against.

## The anonymous API, and why its ceiling is not a constraint here

The GitHub releases endpoint answers `200` **without authentication** — measured on 2026-08-11, so the check needs no token, and a project that never held one still gets a verdict.
The ceiling that comes with it is **60 calls per hour per IP**, shared by everything anonymous on that machine.
The 6-hour cache is what puts it out of scope: one call serves every project of the fleet, whatever their number, and `fleet.sh` reading twelve projects still makes one request. `TEMPLATE_CACHE_MINUTES` moves that window for a test — measured cold, 0.172 s against 0.030 s served from the cache.

## The cache file, and the three ways it was wrong

**Its name is the origin slug, and the separator decides whether two projects share it.** Folding the `/` into a `-` made `acme/proj-tools` and `acme-proj/tools` land on one file, each answering for the other — a wrong verdict, stated with the same confidence as a right one. `%` cannot appear in a GitHub owner or repository name, so the fold is reversible and the collision cannot be built. 🔴 **This is the very ambiguity `fleet.sh` walks the filesystem to avoid, in the same change, left unapplied to the key.**

**It is written aside and moved**, because a plain redirection leaves a half-written file readable — and half a version number reads as a version number to whoever opens it in that instant. A failure to write it is now printed too, after the verdict: the check owes a line on every path, and a cache that cannot be written means the network is called again next session.

**A dead network is remembered for 15 minutes.** Without it the timeout is paid **in full, at every session**, on the most frequent gesture there is: nothing was written on failure, so nothing was there to read next time. Measured with the marker in place: **0.028 s instead of 3 s**. The window is short on purpose — it is a silence, and a silence held too long is indistinguishable from a check that no longer runs.

## Two versions with a different number of parts

`sort -V` ranks `1.2` **below** `1.2.0`, so a two-part stamp against a three-part release reads as late.
Both sides are padded to three parts before being ordered. The generator only ever writes three, so this is a guard against a hand-written stamp and against a fork tagging `v1.2` — never a second supported format.

🔴 **The refusal above has to cover BOTH sides, and it used to cover one.** The stamp is validated where it is read; `latest` comes back from the API, where nothing binds a `tag_name` to be a version number — `v2.0-rc1` reaches the comparison untouched. Padding it produces `2.0-rc1.0`, which `sort -V` will happily order into a verdict nobody can defend. It is refused on the same test as the stamp, and the plugin's own version with it: **a value that cannot be ordered gets a printed line, or silence, never a comparison.**

## The plugin's own line, and why it needed a reference of its own

**The two messages have different addressees**, and conflating them made one of them silent.
The verdict speaks to the **project** — *"the template this project was born from has moved on"* — so it is right that it only concerns generated projects, and right that a stamp carrying a commit hash is refused rather than ordered.
The other speaks to **whoever installed the plugin** — *"the plugin is behind"* — and it exists because Claude Code **does not auto-update a third-party marketplace**.

🔴 **Subordinated to the project's origin, that second line never appeared.** It sat after the verdict, and every earlier exit path — no `AGENTS.md`, no stamp, no origin — exits before reaching it. **Measured on 2026-08-12 with a plugin fourteen versions behind: it spoke in 0 folders out of 10**, this repository included.
It now reads its own `repository` from the manifest, is printed from an `EXIT` trap so no exit path can skip it, and shares the same cache: when the open project comes from that same repository — the ordinary case — the second read costs nothing at all.
⚠️ **A manifest naming no repository gets a printed line, never a guess.** `repository` was chosen because it is what plugin manifests already carry: measured over the 124 installed on this machine, 10 declare it and 12 declare a `homepage`.

## The regression the replay caught, and it is the shape to remember

Extracting one reader for two callers moved the refusal of what `sort -V` cannot order onto the **network** path alone: a value coming back from the **cache** went through unchecked, and a cached value is what almost every session reads.
🔴 The eleven constructed cases were replayed after the extraction, and that is the only reason it was seen — the refactor was small, correct-looking, and green on shellcheck.

## Reading the stamp — the class that stops at the first backtick is not enough

The stamp holds **two** pairs of backticks on one line: the version right after the name, and the generation options further along.
A pattern whose class merely stops at the first backtick reaches the second pair whenever the version is unreadable, and reports `--type static --pages …` **as the version** — measured on 2026-08-11, and the branch meant to say "stamped, no version" was unreachable in the process.
Hence the narrow class: **only markup and spaces** may stand between the name and the version, which is exactly what the generator writes there.
🔴 **Any other shape falls to "stamped, no version", and the line is printed** — a word standing between the name and the backticks, a version that never made it in. The detector recognises **what the generator produces**, and for anything else it states what it read rather than guessing at it.

## Refusing what cannot be ordered

`sort -V` orders numbers. Anything else has to be **refused**, not ordered: it returns an answer either way, and the verdict would be a lie stated with confidence.
🔴 **The case that makes it necessary is `unreleased`**: the generator falls back to that word when the template carries no tag at all, so a project can hold a **well-formed** stamp whose content is not a version — a fork of this tool, generating before it has tagged anything.
Measured: `sort -V` ranks `unreleased` **above** `1.5.0`, so without the refusal the verdict reads `up to date`, which is the failure this whole check exists to avoid.
⚠️ **Reachable by construction, never observed here**: this repository has carried tags since `v1.0.0`, so nothing generated from it since can hold that word.

## Alternatives ruled out

| Ruled out | Why |
|---|---|
| **A check inside the generated project's `checks/`** | The project would carry a script, a wiring line in the control matrix and a second place reading the stamp. The plugin already knows which project is open, so nothing has to travel — decided on 2026-08-11. |
| **Riding `check.sh`'s 6-hour batch** | That rhythm is held by `.githooks/pre-commit`, not by `check.sh`, and the loop running the house checks is conditioned by no mode. Filing the script under `checks/` would have run it at **every** commit. |
| **Comparing the project to the version of the installed plugin** | A plugin left behind would report "up to date". The reference is always the release read online; the plugin's own version is printed **after** the project's verdict, and only as a net for a Claude Code that does not auto-update third-party plugins. |

## Why it never exits non-zero, and never writes

Being a version behind is not a fault: a check that refused a commit for it would be bypassed the same day.
It never rewrites the stamp either — the stamp is a snapshot of the past, and a detector that updated it would destroy the very thing it reads.
