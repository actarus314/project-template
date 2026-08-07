# `configure-repo.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Implementation notes

### `ADMIN_PAT` — the only injection door, and why the recipe pointer stays a pointer

`GH_TOKEN` from the environment is deliberately ignored here: every repo's `.envrc` exports it as
the *write* PAT (without `Administration: write`), so trusting it would silently run this script
under the wrong token. `ADMIN_PAT` is the one explicit door for injecting a token without the
interactive masked prompt (tests, CI) — never something a `.envrc` should set.

The permission recipe printed to the maintainer is a pointer, not a copy: an earlier version copied
it inline, and the copy drifted silently — first missing
`Contents: read` (needed to read `CONTRIBUTING.md`), then `Issues: read` (needed to date the
Dependency Dashboard). That line is exactly what gets read when creating the token, so a short and
wrong recipe is worse than a pointer — each missing permission fails with no error at all.

### Argument parsing — an array, never a rebuilt string

`ARGS` is a bash array, not a string glued back together. A prior version did
`ARGS="$ARGS $a"` then `set -- $ARGS` unquoted: the shell re-word-splits arguments that were
already split. The empty argument (`''`, meaning "no homepage") disappeared — shifting every
later positional argument by one — and the description got cut at its first word. `set --
${ARGS[@]+"${ARGS[@]}"}` keeps the array quoted and stays safe under `set -u` when it's empty.

### The merge-settings PATCH doubles as the Administration preflight

The very first write (`gh repo edit --enable-squash-merge …`) requires `Administration: write`,
so its result is also the first proof that the token can actually write. A 403 there is diagnosed
explicitly (wrong token pasted, or `Administration` left on "Read") instead of surfacing `gh`'s raw
403, which doesn't say which of the two it is.

### `mutate()` — one interception point, and its dry-run stdin trap

A guard per call (there are 14 of them) would have guaranteed missing one, and a dry-run that
writes even once is worse than none — it's the one being trusted. So every write goes through
`mutate()`, gated on `$DRY`.

FD 3 is a copy of the original stdout: almost every call is followed by `>/dev/null 2>&1`, which
would swallow the dry-run message — the script would print its "✓" without ever showing what it
plans to write.

The dry-run branch also drains stdin. Two calls in this script are piped (`… | jq | mutate gh api
--input -`): without draining, `jq` writes into a pipe nobody reads, SIGPIPE fires, and `set -e` +
`pipefail` kill the script mid-run — at the ruleset upsert, without a word (exit 141). Everything
after that was lost silently: the `tags` ruleset (so the version pin), the `develop` ruleset,
community health, and even the reminder to revoke the admin PAT. That failure mode is worst
exactly on a repo that already has a ruleset — bringing an existing repo into compliance — which
is what dry-run exists for. Real mode never had the bug: `gh api --input -` consumes stdin on its
own, `cat` does not unless told to.

`[ -p /dev/stdin ]`, not `[ -t 0 ]`: it needs to detect "this is a pipe", not "this isn't a
terminal". With `-t`, the 12 non-piped calls launched from a non-interactive shell (CI, an agent)
would wait on a `cat` that never returns control — a dry-run that freezes instead of lying.

### `gh_val()` — why `cmd || echo default` is broken, always

`gh api` writes the JSON body of its errors to **stdout**, not stderr. `x=$(gh api … || echo
"default")` therefore captures that JSON, then appends the echo: `x =
'{"message":"Rate Limit Exceeded","status":"403"}default'` — a string equal to nothing. Every
test that follows then goes down the wrong branch, silently: `[ "$x" = "configured" ]` is false,
`[ "$x" -eq 0 ]` blows up, `[ -n "$x" ]` is true even though the call failed.

The fix: `out=$(cmd)` keeps the output even when `cmd` fails, but the assignment's own exit code
tracks the failure. So `gh_val()` tests that code and discards the output on failure, rather than
trusting whatever landed in the variable.

### Dry-run and visibility-gated features — the verdict can't come from the exit code

In dry-run, `mutate()` always "succeeds" — it calls nothing. So for a feature unavailable on a
private Free repo (secret scanning, private vulnerability reporting, Pages, CodeQL), announcing
"✓" from the mutate call's own (fake) success would produce a false compliance report on exactly
the repos being audited with `--dry-run`. Every one of these calls instead decides its own verdict
from `$IS_PRIVATE`, read once up front — before any diagnostic — because misreading it sends the
maintainer looking for a PAT permission that was never the problem.

### Description cleanup — replace, don't delete

The API rejects any control character in a description with a 422. Deleting the character instead
of replacing it glues the surrounding words together — a tab in `"A tool<TAB>for X"` became `"A
toolfor X"`, published as-is, and nobody reread what was actually set. So control characters are
replaced with a space, spaces are then compressed, and what's being set is echoed back so it gets
read once before it's live.

### Immutable releases — verified available on private, not assumed

Immutable releases (repo-controls.md:511,537) are set from private onward, not deferred to the
public flip: the "Enable release immutability" checkbox is present and actionable on a private
Free repo (Settings → General → Releases), with none of the "Upgrade or make this repository
public" banner GitHub shows on features that are actually gated (Wikis, right below it in that
same settings page). Gating this one on visibility anyway would leave the releases of a repo that
never flips to public permanently bare, for no reason — the setting is idempotent, so applying it
early costs nothing, while applying it late can never be recovered (not retroactive).

### Discussions and Pages — read the response back, don't trust the HTTP status

`has_discussions` is not a documented body parameter of `PATCH /repos/{owner}/{repo}`, and the
REST API silently ignores unknown fields instead of erroring. A PATCH that "succeeds" can enable
nothing: a bare `&&` would print a ✓ for a setting that was never applied. Discussions matter
because `.github/ISSUE_TEMPLATE/config.yml` links every generated repo to `/discussions` — without
it, that link 404s on the first third party who tries to ask a question, and nothing signals the
gap to the maintainer.

### Pages — creating the site is an admin action, not a workflow one

`actions/configure-pages`'s `enablement: true` isn't enough: *creating* a Pages site requires
`Administration`, which a workflow's `GITHUB_TOKEN` never has — every deploy would fail with
"Resource not accessible by integration" for as long as the site doesn't exist. So creation is a
one-shot admin action, and this script is where it happens; the workflow only ever deploys to a
site that already exists.

Reading `.github/workflows/pages.yml` to detect the capability requires `Contents: read` on a
private repo (the contents API is open on a public one). Without that permission the read fails,
and treating that failure the same as "no pages.yml" would skip the whole Pages block — homepage
included — silently. So the three cases (workflow present / absent / unreadable) are told apart
explicitly instead of collapsed to two.

### CodeQL — waiting for the first analysis is not a nicety

The `code_scanning` ruleset rule can only be set once an analysis exists. Enabling the default
setup and returning immediately would read "0 analyses" and skip the rule — `main` would then sit
unguarded until someone thinks to rerun the script. So the script waits (up to 6 minutes, polling
every 10s) for the first run to complete before deciding.

The polling loop tells "not finished yet" apart from "not allowed to look": since `gh api` writes
errors to stdout, comparing status against `"completed"` alone can't distinguish a 403 from an
in-progress run — it would spin the full 6 minutes on a permissions problem and continue blind. A
single unreadable response is also not conclusive: GitHub takes a few seconds to materialize a
freshly created run, so a transient 404 right after enabling is normal. Three consecutive
unreadable responses are required before concluding the PAT is missing `Actions: read`.

### The one write that bypasses `mutate()` — and why the invariant is false right there

Enabling CodeQL's default setup is the single write in this script that does **not** go through
`mutate()`. `mutate()` exists only to intercept — it doesn't return the wrapped command's output,
and the `run_id` the PATCH returns is needed to poll for the first analysis. So the dry-run guard
is kept by hand there instead. This means the "one single interception point" invariant claimed
for `mutate()` is false exactly at this call: the dry-run's safety hinges on this one `if`, and on
it alone — any future edit that moved the PATCH out of the `else` branch would write for real,
silently, on a live repo.

The dry-run branch used to print "✓ ENABLED" even on a private repo, where the PATCH is bound to
fail (Advanced Security required) — contradicting itself two lines down ("CodeQL unavailable in
private"). A dry-run promising an impossible setting is worse than a silent one: it gets believed.
It now decides that message from `$IS_PRIVATE` too, like every other visibility-gated call.

### `DS_RUN` must look like an integer, not merely be non-empty

`gh_val '.run_id' ''` on the enabling PATCH can return an error body instead of a `run_id` when
activation actually failed — the same stdout-JSON trap as everywhere else in this script. Without
filtering `DS_RUN` down to "digits only", an error JSON would pass for a run id, the script would
announce "✓ ENABLED" on a repo where CodeQL is in fact unavailable, and the two failure branches
(private / public) that follow would become unreachable dead code.

### `code_scanning` analyses — three states, never collapsed to two

A JSON array (analyses exist), a 404 "no analysis found" (the endpoint works, there's just nothing
yet), and a 403/other (not allowed to look) are three different situations. Treating the 404 like
the 403 accuses the PAT of a permission it already has, and sends the maintainer looking for a
right that was never missing.

### Rulesets — merge, never replace

`upsert_ruleset()` reads the existing ruleset (if any) and only overwrites the rule *types* this
script manages. Rules of a type it doesn't touch — `code_quality` added by hand, or
`code_scanning` before CodeQL has run — are preserved by merging them back in before the PUT. A
bare PUT used to replace the whole ruleset and silently wipe out anything added by hand.
`bypass_actors` on an existing ruleset are reported but never removed automatically — the standard
wants none, but removing an actor is a decision for the maintainer, same as flipping visibility.

### Staging is detected once, up front — never twice

`HAS_DEVELOP` and `WANTS_STAGING` are read before §2, not only where the ruleset step needs them:
§3a (Dependabot security updates) needs the same answer, and a PUT there followed by a DELETE
further down would not be neutral — enabling security updates wakes the bot up on already-open
alerts, and its PR goes out before the later DELETE ever runs.

### `develop` — inferred from what the repo *publishes*, not from the branch's existence

The branch's mere existence used to be the only signal for "this repo runs a staging flow" — and
the control matrix records what that cost the day `delete-branch-on-merge` removed `develop` on the
very promotion that shipped it. **What belongs here is the consequence for THIS script**: seeing no
branch, it concluded "no staging" and aligned every setting on that conclusion, which is how one
deleted branch reconfigured a repository. A cascading failure triggered by success.

So the branch's existence is no longer trusted alone: the repo is also asked what it *publishes*
(`WANTS_STAGING`, read from the `## Branching` section of `CONTRIBUTING.md`). Two probes, because
neither is sufficient alone — the branch can have been destroyed by the promotion while the repo
still documents three stages, and that mismatch is exactly the inconsistency the script flags.

`delete-branch-on-merge` itself is removed whenever a 3-stage repo has no ruleset (private Free):
there, nothing protects `develop` from that same deletion, so the safety net is removed upstream
instead of only warning about the damage after the fact. What's lost is one click of convenience
(`feat/*` still needs manual cleanup); what's avoided is a long-lived branch destroyed silently,
breaking the next promotion. Flipping to public restores it — the ruleset's `deletion` rule takes
over, and the setting is safe to re-enable.

### Dependabot security updates — removed only once Renovate is proven alive, not merely installed

On a 3-stage repo, Dependabot's security PRs always target the default branch and would bypass
`develop`. §3a therefore never sets this safety net there in the first place — this later block
only *removes* the setting for repos configured before that change (or turned on by hand), and
only once Renovate is proven to actually be running: an opted-out repo keeps its Dependency
Dashboard issue intact, so *freshness* of `.updated_at` — not mere existence of the issue — is the
only signal that tells a live bot apart from a dead one (14-day threshold).

`gh api`'s error JSON on stdout is the same trap as `gh_val()` above: without filtering the shape
of `DASH_AT` to an ISO date, a `{"message":"Not Found"}` body compares as *more recent* than any
real date (`{` > `2` in ASCII), and a read failure would have removed the safety net instead of
leaving it in place.

### Classic branch protection — the other system, detected but never deleted

`GET /rulesets` doesn't show it: GitHub carries two independent protection systems on the same
branch, and an existing repo migrated onto this template can still have the old, "classic" one
attached, requiring checks named after its old jobs. Adopting the template's workflows makes those
checks stop existing — the classic rule survives regardless and forever demands a status nothing
will ever produce again: the branch is locked, CI green or not, and `gh pr merge` only answers
"base branch policy prohibits the merge". The two systems stack; setting the ruleset does not
neutralize the classic one. This script only detects and reports it — it doesn't delete, because
the classic rule may carry settings the ruleset doesn't replicate, and destroying a protection is a
decision for the maintainer, same as flipping visibility.

### ghcr image pull — tested anonymously, not assumed

A green "Publish image" job proves nothing about whether the image can actually be *pulled*: this
check queries the registry exactly as the prod host does, anonymously, with no token — the only
test that counts. Package visibility can't be read via the API at all (fine-grained PATs don't
cover GitHub Packages), so this anonymous-pull probe is the only mechanized signal available.

The verdict is `untested` / `ok` / `ko` — three states, not a boolean — because a two-state
`PULL_OK` used to conflate "tested and failed" with "not testable yet", and demanded making a
package public that didn't exist yet on a brand-new repo with no release. Demanding action on a
nonexistent object is the same defect as elsewhere in this script: talking without knowing.

The package's name is read from the workflow's `images:` line, never derived from the slug: it
happens to match the repo name on a *generated* project (`init-project.sh` substitutes
`<image-name>` with it), but a *migrated* repo can publish under any name (`<Repo>` →
`<repo>-collector`). Deriving it made the script test a nonexistent package and wrongly announce
the image as unpullable.

A freshly published package's default visibility depends on the account type — the fact itself, and
what it costs a self-hoster, belong to the control table (`repo-controls.md`, in the template). What matters here
is the consequence for this script: it cannot be derived, so it is **tested anonymously**, and the
"make public" reminder is printed only when that pull actually fails.
