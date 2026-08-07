# `init-project.sh` — why it is written this way

> Convention: [`README.md`](README.md).
> Usage and options are printed by the script itself; repeating them here had already drifted.

## Everything under `checks/` travels, and that is the rule

`check.sh` looks for them THERE; dropped at the root they shipped but never ran — the path died
where the file landed. And **all** of them travel, never a chosen few: a check DETECTS whether its
subject exists where it lands — present, it bites; absent, it says so and returns 0. So "does this one
deserve to travel?" has no addressee: the check answers it at the place, which no list written here
can do. The hooks travel too — they read an event, not a file.

## `docs/code/`: which notes are copied, and which are not

That these notes travel is the charter's to say. What the copy does: `verify-*.md` by glob, plus
`README.md` by name. The generator's own notes — this one, `open-pr.md`, `configure-repo.md` — are
left behind on purpose, and the glob is what leaves them.

`README.md` needs its own line precisely because it is not a `verify-*.md`, and every note opens
with a link to it: left behind, it was by far the largest share of the dead links a generated
project used to be born with.

## The Renovate base branch is INJECTED, never carried

A template hardcoding it would point at a NONEXISTENT `develop` on a two-stage project — and
Renovate without a valid base opens NO PR at all, silently. The failure mode of a botched injection
is the current behaviour (a PR on `main`); the failure mode of the reverse is a dead bot.
The WHY of the key itself: the `description` block of `templates/repo/.github/renovate.json`.

## Two safety nets, and what each deliberately excludes

Net 1 catches placeholders the SCRIPT must substitute; without it every new placeholder replays the
same bug in silence. Net 2 catches placeholders a HUMAN must fill in, in versioned — therefore
published — files. The script cannot guess `<contact>` and must not invent it, but staying silent
is worse: a published `SECURITY.md` saying "reach out to `<contact>`" leaves a researcher with no
way to report a vulnerability. So they are listed, and going public requires them filled in.

`README.md` is excluded on purpose: it is obvious to fill in, and its HTML tags (`<picture>`,
`<p …>`) are false positives that would drown the one message that matters. `LICENSE` too: its year
and holder are substituted just above, and the licence text carries its own canonical URL between
angle brackets, which the pattern would report as a placeholder.

## The lifecycle doc is a SKELETON, and the heredoc is quoted

An empty file does not get filled in, it gets ignored; the sections are exactly the questions
someone — human or AI — asks when reopening the project six months later remembering nothing.
The heredoc is quoted (`'EOF'`) because without the quotes the shell reads the backticks as command
substitution and EMPTIES every `paths` entry in the template. The project name is substituted
afterwards, by `sed`.

## The gitleaks hook is armed AFTER the initial commit

The initial commit is clean by construction (an EXPLICIT file list, never `.env`/`.envrc`), so
there is nothing to scan there. Arming the hook first would require gitleaks to commit this
scaffolding, and the hook hard-failing in its absence would block generation itself — the script
would sabotage itself right after warning that gitleaks is missing. The hook protects DEV commits,
not the scaffolding.

## Two copy traps, neither visible when reading the script

`cp -R src dst` copies **into** `dst` when `dst` already exists, so once the checks' notes began
creating `docs/`, the ADRs landed in `docs/docs/adr/`: present, one level too deep, and no path
dead enough for `verify-travel.sh` to have anything to say. The trailing `/.` copies the CONTENT
instead. And `cp -R` reads the disk rather than git, so untracked macOS index files ride along with
any directory copied whole.

## One home per injected block, one stamp per generation

The branching block goes into `AGENTS.md` alone — it is the authority and the file an agent reads;
`CONTRIBUTING.md` points at it. Injected into both, every generated project was born carrying the
same paragraph twice, in the two files whose job is to teach that rule.

The version stamp is written once, at generation time, from the tag. A generated project holds a
frozen copy of the templates, so the stamp is a snapshot: it stays true about the past even after
the template moves on, and it is what makes assisted regeneration possible at all (`RUNBOOK` §5).
