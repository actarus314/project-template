# `checks/verify-travel.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## What it looks for

A path that resolves here but not where the file lands. Several files travel into every generated project — `check.sh`, `verify-tone.sh`, everything under `templates/` — and a path written in one of them is read by whoever holds that copy, in a project that carries neither `docs/` nor `templates/`.

A grep of the tree cannot see this: it proves no file names a deleted doc, but it is blind to a path that stays written and simply resolves nowhere once it has travelled. That blindness cost two fixes — see `workspace/archives/2026-08-decoupage-par-sujet/SYNTHESE.md`. The only way to see it is to generate a project and read the paths from there.

## The signal is a differential

A path is reported only when it resolves in the template AND fails in the generated project. A generic pattern (`docs/X.md`), a naming example (`docs/adr/0001-short-title.md`) or a URL resolves in neither, so none of them shows up. Measured: 0 reported on a healthy state, 1 on the real defect.

## One generation is not enough, for two opposite reasons

Because the signal is a differential, the poorest tree is the harshest: `generic` ships no capability at all, so a path that survives everywhere else dies there. And a capability brings files of its own — `pages.yml`, `docker-publish.yml` — whose paths are read by nobody unless a variant carrying them is generated. This is not combinatorics: what has to be covered is the set of files that can land, not the set of flag combinations. One generation per toolchain, plus one carrying every capability at once, is what reaches every file. What a single `--type node` run left unread — see `workspace/archives/2026-08-audit-des-controles/SYNTHESE.md`.

## Declaring a path deliberately absent

To declare a path deliberately absent from a generated project, test it — `[ -f x ]`, `[ -x x ]`, or test the folder it lives under (`[ -d templates/repo ]` guards everything below it, a stronger statement than testing each path). A file that checks a path's existence knows it may be missing, and this script honours that: a shell test (negated or not), a Python existence test, or a literal bound to a name tested elsewhere. Requiring the test and the literal on the SAME line was tried first, and reported three checks that guard fine as failures.

## Why the toolchains and capabilities are read, not listed

They come from `init-project.sh`'s own `case` that validates `--type`: one added there is covered the day it is accepted, with nothing here to update. An empty read fails the check rather than skipping it — zero variants would generate nothing, find nothing, and print a tick, which is exactly how a guard goes green and blind.

## Why generation runs muted, and named on failure

`stdout` is muted only for the generation step: what matters is the generated tree, and `init-project.sh` prints its whole next-steps guide there. Its errors stay on stderr and stay visible. The variant is named in the failure message on purpose — a generation that dies without saying which combination died is the "a failing check does not say why" defect, one level up.

## Why a hit is keyed the way it is

A dead path is keyed by `(file, path)`: the same dead path in one file is ONE defect however many variants show it, while the same path in two files is two. The variants that saw it are listed with it — a path dying only under `generic` is a different fact from one dying everywhere.
