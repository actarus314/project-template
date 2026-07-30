# Contributing

This repository **builds and configures** projects — it is not a project itself. Its product is
the **standard**; the scripts are only its automation. Bug reports and fixes are welcome; anything
that changes what the tool *teaches* deserves an issue first.

⚠️ **Read [`AGENTS.md`](AGENTS.md) before touching anything.** It carries the structure, the
commands, the PR-only rule and what must not be broken. It is short, and it is the entry point.

## Before opening a PR

- For anything non-trivial, open an issue first to discuss the approach.
- **Run `./check.sh`.** It replays everything the CI runs, at the pinned versions, locally. What
  passes there passes the CI — the CI remains the authority, but it should not be the first to know.
- Keep code, comments and docs in **English**. The only French left is deliberate: the bilingual
  README template, whose French half *is* the product.
- **One idea per sentence, one sentence per line** in the docs.
- **A fact lives in a single place** — everywhere else, a link. See [`docs/METHODE.md`](docs/METHODE.md).
  A rule copied into two files is a rule that will contradict itself.
- User-facing change — a template that changes, a RUNBOOK step that moves, a script's behaviour?
  Add a line to `CHANGELOG.md` under `Unreleased`. An internal refactor or a typo fix does not go there.

## Branching

`main` only, plus short-lived `feat/…` branches. There is **no `develop`**: this repository has no
host to validate before production — it is read and it is run, it does not deploy.

**Never push to `main` directly.** A `pre-push` hook refuses it.

Open the pull request with `./open-pr.sh <base> <title> <body-file>` rather than by hand: it pushes,
opens the PR, **and verifies that a CI run actually started**. GitHub occasionally fails to dispatch
one, and a PR with **zero runs** reads exactly like a green one while never having been tested.

- Keep commits atomic and messages descriptive.
- **CI must be green before a merge.** Check it:

  ```bash
  sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
  gh run list --commit "$sha"
  ```

  Green means **every expected workflow is `completed / success`**. A workflow **missing** from the
  list is **not** a green: it has not reported yet.

  **After the merge, check the `push` run on `main` too** — a different event, so a different run.
  A PR's green says nothing about that one, and `main` is what ships. ⚠️ That run is found by
  **branch**, not by `--commit`, which returns nothing for a squashed merge.

## Security issues

Don't open a public issue for a security concern — see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree your contributions are licensed under this repository's terms — see
[LICENSE](LICENSE), and [LICENSE-MIT](LICENSE-MIT) for the files this tool copies into the projects
it generates.
