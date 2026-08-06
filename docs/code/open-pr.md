# `open-pr.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The dispatch miss this script exists to close

GitHub intermittently fails to dispatch the `pull_request` workflow run when a PR is opened — even
with a correct, unfiltered `pull_request:` trigger. Observed across repositories carrying an
identical, valid config, so it is not a misconfiguration to fix once: it has to be checked every
time. A PR that received zero runs looks exactly like one that passed — "0 runs" silently reads as
"nothing wrong" — so it gets merged unchecked. `AGENTS.md` carries the resulting discipline
("`0 runs` is never a green"); this script is what makes that discipline mechanical instead of
remembered.

## Why close/reopen, and not `workflow_dispatch`

`close` then `reopen` is the **only** re-trigger that reproduces a repository's **required**
`pull_request` checks (e.g. `checks`, `build-check`). A `workflow_dispatch` run is a real run, but
it does not satisfy a required `pull_request` context — a branch ruleset would still show the PR as
unchecked even after it ran. That is why the retry re-fires the event itself rather than invoking
the workflow directly.

## Why it waits before opening, not just before checking

Opening the PR immediately after `git push` is the main cause of the missed dispatch: GitHub has
not yet registered the head commit, so the `pull_request` event has nothing to attach a run to.
Waiting for `gh api repos/$REPO/commits/$SHA` to succeed first shrinks that push → open race — it
does not eliminate the dispatch miss (nothing here can), but it removes the largest share of it
before the harder retry path is ever needed.
