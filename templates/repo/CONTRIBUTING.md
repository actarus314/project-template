# Contributing

This is a small, solo-maintained project — there's no formal process, but bug
reports, fixes, and small improvements are welcome.

## Before opening a PR

- For anything non-trivial, open an issue first to discuss the approach.
- Run it locally and check the change actually works.
- Keep code and comments in **English**.
- No new dependencies for what a few lines of code can do.
- User-facing change (a fix, a feature, a behavior change)? Add a line to the CHANGELOG.

<!-- BRANCHING -->

- Keep commits atomic and messages descriptive.
- **CI must be green before a merge.** Check it:

  ```bash
  sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
  gh run list --commit "$sha"
  ```

  Green means **every expected workflow is `completed / success`** — `CI`, plus `Publish image`
  when the project publishes an image, plus **`CodeQL` once the repository is public** (it does
  not run while private). A workflow **missing** from the list is **not** a green: it has not
  reported yet.

  ⚠️ **Match on `workflowName`, not on `name`.** CodeQL runs through GitHub's *default setup*, so
  it has no workflow file: its `name` reads `Push on main` — the run's title. Only `workflowName`
  says `CodeQL`.

  While the repository is **private**, this is *not* enforced by the server: a Free-plan private
  repo has no rulesets, so GitHub would accept the merge of a red pull request, and a direct push
  to `main`. A `pre-push` hook refuses the direct push; **nothing refuses the red merge but the
  person doing it**. Once the repository is public, the ruleset enforces this and the rule stops
  depending on anyone's memory.

## Vendored bundle

<!-- Keep this section only if the project vendors a third-party bundle. -->

If the project vendors a third-party bundle: after upgrading it, regenerate
its `.sha256` checksum, commit both files together, and re-test in a browser.
CI verifies the checksum matches — a stale one fails the build.

## Security issues

Don't open a public issue for a security concern — see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree your contributions are licensed under the project's license — see [LICENSE](LICENSE).
