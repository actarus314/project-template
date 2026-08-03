# Contributing

This repository **builds and configures** projects — it is not a project itself.
Bug reports and fixes are welcome; anything that changes what the tool *teaches* deserves an issue first.

⚠️ **Read [`AGENTS.md`](AGENTS.md) before touching anything.**
It is the entry point, and it is short: the structure, the commands, the PR-only rule, the conventions, and what must not be broken.
**It is also the authority** — this page holds only what it does not, so that no rule here can drift from the rule there.

## What this page adds

- For anything non-trivial, **open an issue first** to discuss the approach.
- Keep commits **atomic**, and their messages descriptive.
- Branch off `main`, with short-lived `feat/…` branches.
  There is **no `develop`**: this repository has no host to validate before production — it is read and it is run, it does not deploy.

## Everything else lives in `AGENTS.md`

Each of these was written here too, until the two copies started to disagree — the merge check in this file had already lost the `--json` filter that makes its result readable.

| To… | Read |
|---|---|
| replay the CI locally before pushing | **Commands** — `./check.sh` |
| open the pull request, and confirm the CI actually started | **Discipline — PR-only** — `./open-pr.sh` |
| verify a green before merging, then the `push` run on `main` | **Discipline — PR-only** |
| know which language to write in, and how to lay a doc out | **Conventions** |
| decide whether a change earns a `CHANGELOG` line | **Conventions** |
| avoid the four things that break silently | **Do not break** |

## Security issues

Don't open a public issue for a security concern — see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree your contributions are licensed under this repository's terms — see
[LICENSE](LICENSE), and [LICENSE-MIT](LICENSE-MIT) for the files this tool copies into the projects
it generates.
