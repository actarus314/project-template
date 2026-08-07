# `init-project.sh` — why it is written this way

> Convention: [`README.md`](README.md).
> Usage and options are printed by the script itself; repeating them here had already drifted.

## Everything under `checks/` travels, and that is the rule

`check.sh` looks for them THERE; at the root they shipped unrun. All travel, never a chosen few: a check DETECTS whether its subject exists where it lands — present it bites, absent it says so and returns 0. So "does this one deserve to travel?" has no addressee: the check answers at the place, which no list here can. Hooks travel too — they read an event, not a file.

## `docs/code/`: which notes are copied, and which are not

That these notes travel is the charter's to say. The copy: `verify-*.md` by glob, plus `README.md`
by name. The generator's own — this one, `open-pr.md` — are left behind, and the glob leaves them.
`configure-repo.md` is the exception: its script travels, so its note does.

`README.md` needs its own line: it is not a `verify-*.md`, and every note opens with a link to it: left behind, it was the largest share of the dead links a project used to be born with.

## The Renovate base branch is INJECTED, never carried

A template hardcoding it would point at a NONEXISTENT `develop` on a two-stage project — and Renovate without a valid base opens NO PR at all, silently. A botched injection fails as the current behaviour (a PR on `main`); the reverse fails as a dead bot.
The WHY of the key: the `description` block of `templates/repo/.github/renovate.json`.

## Two safety nets, and what each deliberately excludes

Net 1 catches placeholders the SCRIPT must substitute; without it every new one replays the bug in silence. It **skips what is copied verbatim from the root**: never substituted, and those files are the ones that *document* the placeholders — scanned, prose reads as a defect. ⚠️ The CI holds its own copy of this net *(the one here warns without failing)*, and the two had already drifted apart. Net 2 catches those a HUMAN must fill in, in published files. The script cannot guess `<contact>`
and must not invent it, but silence is worse: a published `SECURITY.md` saying "reach out to `<contact>`" leaves a researcher no way to report a vulnerability. So they are listed, and going public requires them filled in.

`README.md` is excluded on purpose: its HTML tags (`<picture>`, `<p …>`) are false positives that would drown the one message that matters. `LICENSE` too: its year and holder are substituted just above, and its canonical URL sits between angle brackets, which the pattern would report.

## The lifecycle doc is a SKELETON, and the heredoc is quoted

An empty file does not get filled in, it gets ignored; the sections are the questions someone — human or AI — asks reopening the project six months later. The heredoc is quoted (`'EOF'`): without the quotes the shell reads the backticks as command substitution and EMPTIES every `paths` entry.
The project name is substituted afterwards, by `sed`.

## The gitleaks hook is armed AFTER the initial commit

The initial commit is clean by construction (an EXPLICIT file list, never `.env`/`.envrc`), so there is nothing to scan. Arming it first would need gitleaks to commit this scaffolding, and the hook hard-failing in its absence would block generation — the script sabotaging itself right after warning that gitleaks is missing. It protects DEV commits, not the scaffolding.

## The image reference is lowercased at the source

`metadata-action` lowercases the pushed image, but not the reference written in plain text inside `docker-publish.yml`'s own release notes (its `image:` block) — left uppercase there, a repo name like `MyRepo` announces a `docker pull` nobody can run. `configure-repo.sh` already lowercases its own side; the generator aligns with it here instead of leaving the mismatch to be found later.

`docker-publish.yml` also needs its own `<owner>/<repo>` substitution, not just `<image-name>`: it is copied AFTER the global substitution pass above runs, so that pass never saw it. Its `cosign verify` comment cites the slug — left unsubstituted, it would teach verifying an identity that does not exist.

## `docker-publish.yml` carries the ONLY `release` job

Keeping a separate `release.yml` alongside it would not divide the work, it would race it: both fire on the same tag, and `needs: build-push` only holds the job still attached to it. Whichever workflow starts first wins, regardless of whether the image actually published — so a release could announce an image that never shipped. One file owns the release job; the other is deleted on generation.

## Two copy traps, neither visible when reading the script

`cp -R src dst` copies **into** `dst` when `dst` exists, so once the checks' notes began creating `docs/`, the ADRs landed in `docs/docs/adr/`: present, one level too deep, and no path dead enough for `verify-travel.sh` to say anything. The trailing `/.` copies the CONTENT. And `cp -R` reads the disk, not git, so untracked macOS index files ride along with any directory copied whole.

## One home per injected block, one stamp per generation

The branching block goes into `AGENTS.md` alone — it is the authority and the file an agent reads;
`CONTRIBUTING.md` points at it. Injected into both, every generated project was born carrying the same paragraph twice, in the two files whose job is to teach that rule.

The stamp also carries the **options**, every flag explicit, negatives included: regeneration reproduces the project *(`RUNBOOK` §5)*, so a shortcut whose default moves later would reproduce a **different** one, silently. Written it is exact; deduced from the tree, inferred. A generated project holds a frozen copy of the templates, so the stamp is a snapshot: it stays true about the past even after the template moves on, and it is what makes assisted regeneration possible at all (`RUNBOOK` §5).
