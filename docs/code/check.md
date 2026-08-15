# `check.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Why shell and `python3`, and not a faster language

The question is worth settling once, with numbers, because it comes back. Measured on 2026-08-07 (Darwin arm64): starting `bash` costs **6 ms**, `python3` **20 ms**, `node` **33 ms**; one `git`
call costs **11 to 14 ms**. The checks make **123 `git` calls**.

The gate's wall clock therefore sits in `git` and in real work — generating a project, replaying the gate inside it — never in interpretation. That cost is **identical from Go, Rust or C**: `git` is an external binary, and the `fork/exec` is paid the same by any caller. Rewriting the checks removes none of those calls, and the two obvious candidates *start slower than the shell they would replace*.

A compiled language would drop the startup cost, and that is where the argument ends: these checks are **copied into every generated project**, for people who compile nothing. `bash` and `python3`
are on any macOS or Linux; shipping Go or Rust would mean per-platform binaries, or a toolchain to install — to save milliseconds that are not where the time goes.

⚠️ **The one real saving is not a language change.** The gate's checks start `python3` **18 times**
(~360 ms if all of them run, under a tenth of the gate); several scripts start it three or four times to read three fields of the same payload. One launch per script would return most of that.
The hooks start it 25 more times — outside the gate, but on every turn.

## Why `GIT_INDEX_FILE` is cleared

Measured 2026-08-15: git exports it *relative* only for a hand-staged commit; `commit -a` and `commit <path>` export it **absolute**, no worktree needed, and that survives `git -C`. Under it **11 of the 22 house checks** answered about the wrong repository, 8 staying green on a false count.

Its ground had no user: through a real partial commit, with the variable then without, **0 check changed verdict**. Nothing is reinjected. Wrapping each `git -C` was dropped — seven files, no cover for the next.

## The two checks that GENERATE a project run in the parallel lot

They were once run alone, after the lot, on the stated grounds that they generate a whole project.
Run in sequence they dominated the gate by themselves — 5,9 s of 9,1 s — and nothing required it:
each works inside its own `mktemp -d`, and the `check.sh` a generated project runs writes to *its* cache, since `CACHE` is a relative path. Moved into the lot, the gate went to 3,95 s with verdicts captured before and after and diffed as identical.

**What the loop really excludes is a hook**, and for a reason that has nothing to do with generating anything — `verify-checks-wiring.md` states it, and it is not restated here.
