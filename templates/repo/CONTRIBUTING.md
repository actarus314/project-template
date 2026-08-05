# Contributing

This is a small, solo-maintained project — there's no formal process, but bug
reports, fixes, and small improvements are welcome.

## Before opening a PR

- For anything non-trivial, open an issue first to discuss the approach.
- Run it locally and check the change actually works.
- Keep code and comments in **English**.
- No new dependencies for what a few lines of code can do.
- User-facing change (a fix, a feature, a behavior change)? Add a line to the CHANGELOG.

- Keep commits atomic and messages descriptive.
- **CI must be green before a merge**, and while the repository is private **nothing on the server
  enforces that** — the rule is held by whoever merges. The exact command, what counts as green,
  and the two absences that are normal rather than failures: **[`AGENTS.md`](AGENTS.md)**.

## Everything else lives in `AGENTS.md`

`AGENTS.md` is the authority, and this page holds only what it does not — each of the lines below
was written in both files until the two copies started to disagree.

| To… | Read in [`AGENTS.md`](AGENTS.md) |
|---|---|
| know which branch to start from, and where the pull request goes | **Branching** |
| verify a green before merging, then the `push` run on `main` | **While the repository is PRIVATE** |
| replay the CI locally before pushing | **Checks that run** — `./check.sh` |
| open the pull request and confirm the CI actually started | **Checks that run** — `./open-pr.sh` |
| know which language to write in, and the conventions that apply | **Conventions** |
| decide whether a change earns a `CHANGELOG` line | **Conventions** |

## Vendored bundle

<!-- Keep this section only if the project vendors a third-party bundle. -->

If the project vendors a third-party bundle: after upgrading it, regenerate
its `.sha256` checksum, commit both files together, and re-test in a browser.
CI verifies the checksum matches — a stale one fails the build.

## Security issues

Don't open a public issue for a security concern — see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree your contributions are licensed under the project's license — see [LICENSE](LICENSE).
