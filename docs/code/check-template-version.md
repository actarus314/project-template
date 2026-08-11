# `hooks/check-template-version.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What it compares, and the limit that comes with it

It compares the project's origin stamp to the **latest published release** of the template, never to `main`.
A change merged an hour ago is therefore invisible to it, and that is the intended reach: the stamp says which version the project was generated from, so a release is the only thing it can be ordered against.

## The anonymous API, and why its ceiling is not a constraint here

The GitHub releases endpoint answers `200` **without authentication** — measured on 2026-08-11, so the check needs no token, and a project that never held one still gets a verdict.
The ceiling that comes with it is **60 calls per hour per IP**, shared by everything anonymous on that machine.
The 6-hour cache is what puts it out of scope: one call serves every project of the fleet, whatever their number, and `fleet.sh` reading twelve projects still makes one request. `TEMPLATE_CACHE_MINUTES` moves that window for a test — measured cold, 0.172 s against 0.030 s served from the cache.

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
