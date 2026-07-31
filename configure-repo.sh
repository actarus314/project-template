#!/usr/bin/env bash
set -euo pipefail

# Configures the SERVER settings of a public GitHub repo per the standard.
# One-shot, IDEMPOTENT (rerunnable without creating a duplicate).
#
# ⚠ Run by THE MAINTAINER — NEVER by the assistant, which never has Administration: write
#   (PAT matrix: see docs/github-repo-config.md §2).
#
# AUTH — EPHEMERAL fine-grained PAT, to create then REVOKE right after:
#   Permissions: EXACT recipe in docs/RUNBOOK.md, step 7a
#   (a missing permission fails SILENTLY).
#   · "Only select repositories" = THIS repo only  → blast radius = 1 repo
#   · Create/revoke: https://github.com/settings/personal-access-tokens
#
#   The token is stored NOWHERE: not in the keychain, not in .envrc, not in shell history.
#   The script asks for it as MASKED INPUT (or reads GH_TOKEN if already exported).
#   Nothing to remove or forget afterwards: the token is revoked, its rights are never downgraded.
#
# Usage: ./configure-repo.sh <owner>/<repo> [homepage-url] [description] [topics-csv] [--dry-run]
#
# What "Use this template" / init-project.sh do NOT do (server config):
# merge-methods, delete-branch, secret scanning, push protection, Dependabot,
# CodeQL, ruleset. This script is the one that sets them.
#
# --dry-run: READS everything, WRITES nothing. Diagnostics (visibility, plan, CodeQL, community)
#   stay REAL — they are GETs, harmless. Only MUTATIONS are intercepted and
#   displayed. Used to run the script on a LIVE repo without risking anything: this is exactly
#   the case of bringing existing repos into compliance, where a mistake isn't an option.

DRY=0
# An ARRAY, not a string. With `ARGS="$ARGS $a"` then `set -- $ARGS` (unquoted), the shell
# redid word splitting on arguments already split: the EMPTY argument (`''` for "no
# homepage") DISAPPEARED — shifting everything by one — and the description got CUT at its first
# word.
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --version) echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}   # `${ARGS[@]+…}`: stays safe under `set -u` when the array is empty

SLUG="${1:?Usage: configure-repo.sh <owner>/<repo> [homepage-url] [description] [topics-csv] [--dry-run]}"
HOMEPAGE="${2:-}"
DESCRIPTION="${3:-}"
TOPICS="${4:-}"   # csv: "solana,bridge,web3"

case "$HOMEPAGE" in
  ""|https://*|http://*) ;;
  *) echo "✗ invalid homepage: \"$HOMEPAGE\" — expected a URL (https://…) or an empty string."
     echo "  A non-URL homepage is published as-is on the repo page: a dead link."
     echo "  Usage: ./configure-repo.sh <owner>/<repo> [homepage-url] [description] [topics-csv] [--dry-run]"
     exit 1 ;;
esac

# ONE SINGLE interception point for ALL writes. A guard per call (there are 14 of them)
# would have guaranteed missing one — and a dry-run that writes even once is worse than none,
# since it's the one being trusted.
#
# ⚠ FD 3 = copy of the ORIGINAL stdout. Essential: almost every call is followed by
#   `>/dev/null 2>&1`, which would SWALLOW the dry-run message — the script would display its "✓"
#   without ever showing what it plans to write. A silent dry-run is worse than no dry-run at all.
exec 3>&1
mutate() {
  if [ "$DRY" -eq 1 ]; then
    printf '  [dry-run] WOULD WRITE: %s\n' "$*" >&3
    # DRAIN stdin, otherwise the dry-run KILLS ITSELF. Two calls are PIPED (`… | jq | mutate gh api
    # --input -`): without reading, jq writes into a pipe nobody opens → SIGPIPE, and
    # `set -e` + `pipefail` kill the script AT THE RULESET UPSERT — without a word (exit 141).
    # Everything after that was then LOST SILENTLY: the `tags` ruleset (so the pin from §13), the
    # `develop` ruleset, community health, and even the reminder to REVOKE THE ADMIN PAT. Yet it's
    # precisely on a repo that ALREADY HAS a ruleset — bringing an existing repo into compliance — that dry-run is meant for.
    # Real mode never had the bug: `gh api --input -` consumes stdin, that one does.
    # `-p`, NOT `-t`: it needs to drain THE PIPE, not "anything that isn't a terminal". With
    # `[ -t 0 ]`, the 12 non-piped calls launched from a non-interactive shell (CI, agent) would have
    # waited on a `cat` that never returns control: a dry-run that freezes instead of lying.
    [ -p /dev/stdin ] && cat >/dev/null 2>&1
    return 0
  fi
  "$@"
}

# ═══ gh_val <jq-expr> <default> <gh api args…> — READ a value, or return the DEFAULT ═══════════
#
# 🔴 NEVER WRITE `x=$(gh api … || echo "default")`. THIS IS BROKEN, ALWAYS.
#    `gh api` writes the JSON body of its errors to **STDOUT**, not to stderr. The substitution
#    therefore captures THIS JSON, *then* appends the `echo`:
#        x = '{"message":"Rate Limit Exceeded","status":"403"}default'
#    — a string that is equal to NOTHING. Every test that follows then goes down the wrong
#    branch, SILENTLY: `[ "$x" = "configured" ]` is false, `[ "$x" -eq 0 ]` blows up, `[ -n "$x" ]`
#    is TRUE even though the call FAILED.
#
#    The rule: `out=$(cmd)` KEEPS the output even when `cmd` fails — but the ASSIGNMENT itself
#    inherits the return code. So test THAT code, and DISCARD the output. That is the whole fix.
gh_val() {
  local expr="$1" fb="$2"; shift 2
  local out
  out=$(gh api "$@" --jq "$expr" 2>/dev/null) || { printf '%s' "$fb"; return 0; }
  [ -n "$out" ] || { printf '%s' "$fb"; return 0; }
  printf '%s' "$out"
}

if [ "$DRY" -eq 1 ]; then
  echo "══ --dry-run MODE: read-only. No writes. The ✓ below should be read as \"would have set\". ══"
fi

command -v gh >/dev/null || { echo "✗ gh CLI required"; exit 1; }
command -v jq >/dev/null || { echo "✗ jq required"; exit 1; }

# EPHEMERAL Administration PAT — entered BY HAND, never stored (no keychain, no file).
# GH_TOKEN from the ENVIRONMENT is deliberately IGNORED: every repo's .envrc exports it = the WRITE
# PAT (without Administration: write). ADMIN_PAT is the ONLY injection door, EXPLICIT (tests/CI)
# — never a .envrc.
if [ -n "${ADMIN_PAT:-}" ]; then
  GH_TOKEN="$ADMIN_PAT"
else
  # ⚠ DO NOT re-copy the recipe here. This line listed it once, and the copy DRIFTED silently:
  #   it was missing `Contents:read` (to read CONTRIBUTING.md) then `Issues:read` (to date the
  #   Dependency Dashboard). Yet this very line is what gets read when creating the token — a short
  #   and wrong recipe is worse than a pointer, and each missing permission fails SILENTLY.
  printf 'Ephemeral admin PAT on %s — EXACT recipe: docs/RUNBOOK.md, step 7a\n' "$SLUG" >&2
  printf '  (a missing permission raises NO error: the missing check does not show)\n' >&2
  printf 'Masked input: ' >&2
  GH_TOKEN=""                        # clear BEFORE the read: a read without a tty would leave the env GH_TOKEN (the write PAT)
  read -rs GH_TOKEN < /dev/tty || true
  printf '\n' >&2
fi
export GH_TOKEN
[ -n "${GH_TOKEN:-}" ] || { echo "✗ No token provided."; exit 1; }

echo "→ Server configuration for $SLUG"

# ⚠ Read visibility BEFORE any diagnostic. Without it, the script would accuse the PAT of a missing
#   permission where it's actually the PLAN that blocks (private/Free) — sending the maintainer to look
#   for a right that's already there. It is the FOUNDATION of the diagnostic: unreadable, stop here —
#   otherwise every downstream message would accuse the wrong cause, silently. A clean failure beats a false report.
IS_PRIVATE=$(gh api "repos/$SLUG" --jq '.private' 2>/dev/null || true)
if [ "$IS_PRIVATE" != "true" ] && [ "$IS_PRIVATE" != "false" ]; then
  echo "✗ Visibility of $SLUG unreadable — the PAT can't see the repo (wrong slug, expired PAT, or out of scope)."
  echo "  Stopping: without it, this script's diagnostics would accuse the wrong cause."
  exit 1
fi

# 1. Merge: squash ONLY + delete branch on merge (clean history). This is ALSO the
#    Administration PREFLIGHT: this PATCH is the 1st write and requires Administration:write. In
#    real mode, a 403 here = a token without Administration (wrong token pasted, or "Read" instead
#    of "Read and write") — this is SAID explicitly, instead of gh's raw 403 which doesn't show the cause.
if [ "$DRY" -eq 1 ]; then
  mutate gh repo edit "$SLUG" \
    --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false --delete-branch-on-merge
elif ! gh repo edit "$SLUG" \
    --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false --delete-branch-on-merge; then
  echo "✗ The token provided can see $SLUG but does NOT have Administration:write — write refused."
  echo "  → either this isn't the admin PAT (the write PAT may have been pasted by mistake),"
  echo "    or Administration was left on \"Read\" instead of \"Read and write\"."
  echo "  Recreate the admin PAT (RUNBOOK §1 step 7a: Administration = Read and write) then rerun."
  exit 1
fi
[ -n "$HOMEPAGE" ] && mutate gh repo edit "$SLUG" --homepage "$HOMEPAGE"
# The description counts toward community health (100% is unreachable without it) and requires
# Administration: the assistant gets a 403 — only this script can set it.
# The API rejects with 422 any control character ("description control characters are not
# allowed") — a copy-paste from a terminal or a doc easily slips one in, invisibly.
# They are stripped, and what was stripped is reported rather than done silently.
if [ -n "$DESCRIPTION" ]; then
  # REMOVING a control character leaves a HOLE in its place: "organization,··public" — two
  # spaces where the invisible character stood. The guard did avoid the 422, but it
  # PUBLISHED a damaged description, and nobody reread what was actually set.
  # → clean up, THEN glue back together (`tr -s ' '` compresses spaces), THEN READ IT BACK OUT LOUD.
  # `tr ' '` and NOT `tr -d`: DELETING a control character GLUES the surrounding words together —
  # a tab in "A tool<TAB>for X" gave "A toolfor X", published as-is. It is REPLACED
  # with a space, THEN spaces are compressed, THEN what's being set is read back out loud.
  CLEAN=$(printf '%s' "$DESCRIPTION" | LC_ALL=C tr '\000-\037\177' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//')
  if [ "$CLEAN" != "$DESCRIPTION" ]; then
    echo "  ⚠ description cleaned (control characters / duplicate spaces — the API refuses the former with a 422):"
    echo "    → \"$CLEAN\""
  fi
  mutate gh repo edit "$SLUG" --description "$CLEAN"
fi
if [ -z "$DESCRIPTION" ] && [ -z "$(gh api "repos/$SLUG" --jq '.description // ""')" ]; then
  echo "  ⚠ no description on the repo → community health capped at 85%."
  echo "    Set it: ./configure-repo.sh $SLUG '' '<description>'"
fi
# Topics REQUIRE Administration:write (`PUT /repos/{o}/{r}/topics` → `administration=write`)
# — so the assistant, which NEVER has `Administration: write`, gets a 403: ONLY this script can set them.
# `--add-topic` ADDS, it does not overwrite what's there.
if [ -n "$TOPICS" ]; then
  mutate gh repo edit "$SLUG" --add-topic "$TOPICS"
elif [ "$(gh_val '.names | length' 0 "repos/$SLUG/topics")" -eq 0 ]; then
  echo "  ⚠ no topics on the repo → it surfaces in NO GitHub search by subject."
  echo "    Set them: ./configure-repo.sh $SLUG '' '' 'topic-a,topic-b'"
fi
echo "  ✓ merge and delete-branch-on-merge (BOTH revisited below based on 'develop')${HOMEPAGE:+, homepage}${DESCRIPTION:+, description}${TOPICS:+, topics}"

# Discussions — the `.github/ISSUE_TEMPLATE/config.yml` template points to `/discussions` on
# EVERY generated repo. Without this being enabled, that link is a 404: the first third party
# trying to ask a question lands on a dead page, and nothing signals it to the maintainer. Set here
# rather than in the runbook — the script already holds the admin PAT that this activation requires.
mutate gh api -X PATCH "repos/$SLUG" -F has_discussions=true >/dev/null 2>&1 || true
# READ IT BACK, and don't trust the exit code: `has_discussions` is not a documented bodyParameter
# of `PATCH /repos/{owner}/{repo}`, and REST ignores an unknown field WITHOUT an error. The PATCH then
# returns 200 while enabling nothing, and a `&&` would show a ✓ for a setting that was never set.
if [ "$DRY" -eq 1 ] || [ "$(gh_val '.has_discussions' false "repos/$SLUG")" = "true" ]; then
  echo "  ✓ Discussions open (without them, the 'Question / Discussion' link in the issue template is a 404)"
else
  echo "  ⚠ Discussions STILL closed — the 'Question / Discussion' link in the issue template is a 404."
  echo "    Open them in the UI: https://github.com/$SLUG/settings → Features → Discussions"
fi

# 2. Security features (ADMINISTRATION).
#    ⚠ On a personal account (non-org), some sub-keys can be no-ops —
#      confirm afterwards in Settings → Code security.
SS_OK=0
mutate gh api -X PATCH "repos/$SLUG" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' \
  >/dev/null 2>&1 || SS_OK=1
# 🔴 IN DRY-RUN, THE VERDICT CANNOT COME FROM THE RETURN CODE: `mutate` ALWAYS succeeds (it
#    calls nothing). The ✓ would therefore show even where the call is BOUND to fail — and on a
#    private Free repo, secret scanning is UNAVAILABLE. Yet dry-run is precisely the tool used to
#    audit a LIVE repo without risking anything: letting it announce "set" produces a FALSE
#    COMPLIANCE REPORT, exactly on the private repos being audited. So the branch is decided on VISIBILITY.
#    (Same guard as CodeQL further below — it was set for that one call only, never generalized.)
if [ "$DRY" -eq 1 ]; then
  [ "$IS_PRIVATE" = "true" ] && SS_OK=1 || SS_OK=0
fi
if [ "$SS_OK" -eq 0 ]; then
  echo "  ✓ secret scanning + push protection"
else
  echo "  ⚠ secret scanning / push protection: NOT enabled."
  echo "    Expected on a PRIVATE repo on the Free plan (unavailable — standard §18):"
  echo "    the gitleaks pre-commit hook is then the ONLY anti-secret safety net."
  echo "    → REPLAY this script when flipping to public."
fi

# Three-stage flow? Detected RIGHT HERE, not only in §12 which also uses it: §3a needs to know
# whether to set the Dependabot safety net. A PUT followed by a DELETE further down would NOT be neutral —
# enabling security updates WAKES the bot up on ALREADY open alerts, and the PR goes out before the DELETE.
#   TWO probes, because neither is enough alone: the branch may have been DESTROYED by the
#   promotion (see §12), and the repo still publish a three-stage flow regardless. `CONTRIBUTING.md`
#   is versioned, and its `## Branching` block is composed by init-project.sh based on the STAGING
#   capability: if it announces 3 stages, the branch MUST exist — that's what §12 handles the gap for.
HAS_DEVELOP=0
gh api "repos/$SLUG/branches/develop" >/dev/null 2>&1 && HAS_DEVELOP=1
WANTS_STAGING=0
gh api "repos/$SLUG/contents/CONTRIBUTING.md" --jq '.content' 2>/dev/null \
  | base64 -d 2>/dev/null | grep -q 'Three stages' && WANTS_STAGING=1

# 3. Dependabot alerts — CVE DETECTION (native, free in private). Kept: Renovate READS it
#    (vulnerabilityAlerts) to open its remediation PRs. Without it, no Renovate security PR.
mutate gh api -X PUT "repos/$SLUG/vulnerability-alerts" >/dev/null 2>&1 \
  && echo "  ✓ Dependabot alerts (detection — Renovate reads these for its security PRs)" \
  || echo "  ⚠ vulnerability-alerts: failed — check in the UI"

# 3a. Dependabot security updates — the SAFETY NET, set ONLY on two-stage flows: on three stages its
#     PRs would target `main` and bypass staging (removed further below for the prior state).
#     The why, and the proof-of-life of Renovate that gates the removal: standard, "Who updates
#     dependencies".
#     ⚠ DEDICATED ENDPOINT, not a sub-key of `security_and_analysis`: `dependabot_security_updates`
#       appears in the RESPONSE schema of GET /repos, but NOT in the PATCH body-params.
#       Passing it to PATCH raises no error — it's simply ignored, SILENTLY. A setting believed
#       set because the call answered 200 is worse than a setting that's absent.
#     Must follow `vulnerability-alerts`: security updates have nothing to remediate without detection.
if [ "$HAS_DEVELOP" -eq 0 ] && [ "$WANTS_STAGING" -eq 0 ]; then
  mutate gh api -X PUT "repos/$SLUG/automated-security-fixes" >/dev/null 2>&1 \
    && echo "  ✓ Dependabot security updates (safety net)" \
    || echo "  ⚠ automated-security-fixes: failed — check Settings → Advanced Security."
fi

# 3b. Private vulnerability reporting — WITHOUT IT, THE SECURITY.md LINK IS DEAD.
#     SECURITY.md points to /security/advisories/new: if the feature is disabled,
#     an external researcher has NO WAY to report a flaw privately… and will
#     therefore publish it as a public issue, before any fix. Free, no upkeep.
#     PVR is **public-only**: it's a VISIBILITY gate, not a plan gate. In dry-run the `✓`
#     below would therefore be wrongly announced on a private repo — same guard as in §2.
PVR_OK=0
mutate gh api -X PUT "repos/$SLUG/private-vulnerability-reporting" >/dev/null 2>&1 || PVR_OK=1
# ⚠ `[ a ] && [ b ] && x=1` ALONE on its line would return 1 when the test is false — and `set -e`
#   would kill the script. The `if` isn't a style choice: it's what keeps it alive in real mode.
if [ "$DRY" -eq 1 ] && [ "$IS_PRIVATE" = "true" ]; then PVR_OK=1; fi
if [ "$PVR_OK" -eq 0 ]; then
  echo "  ✓ private vulnerability reporting (the SECURITY.md link works)"
elif [ "$IS_PRIVATE" = "true" ]; then
  echo "  ↳ private vulnerability reporting: MOOT while private (no external researcher can reach it)."
  echo "    Will be set on the flip to public — that's when it becomes essential."
else
  echo "  ⚠ private vulnerability reporting: FAILED on a PUBLIC repo → the SECURITY.md link is DEAD."
  echo "    A researcher then has no way to report privately: they will publish the flaw."
fi

# 3d. IMMUTABLE RELEASES — the RELEASE-side counterpart of the 'tags' ruleset (§13).
#     The 'tags' ruleset pins the tag; this one pins the release's ASSETS. Without both,
#     the prod pin `APP_IMAGE_TAG=1.2.3` remains bypassable: the tag isn't moved,
#     the binary attached under that same tag is swapped instead.
#     🔴 NOT RETROACTIVE: "immutability will only apply to future releases". This is what dictates
#       the timing: set it AS EARLY AS POSSIBLE, without waiting, because whatever isn't covered at
#       the time of a release's publication NEVER will be.
#     ⚠ SET FROM PRIVATE ALREADY — and specifically NOT gated on public. The setting IS available on
#       a private Free repo: the "Enable release immutability" checkbox is present and actionable
#       (Settings → General → Releases), without the "Upgrade or make this repository public" banner
#       that GitHub shows on features that are actually gated (Wikis, right below it).
#       Gating it would leave the releases of a repo that never flips to public PERMANENTLY bare —
#       and the tradeoff is asymmetric: setting it early costs nothing (idempotent),
#       setting it too late can never be recovered.
#     PUT with no body → 204. GET returns { enabled, enforced_by_owner }.
if mutate gh api -X PUT "repos/$SLUG/immutable-releases" >/dev/null 2>&1; then
  echo "  ✓ immutable releases (a published release's assets can no longer be replaced)"
else
  echo "  ⚠ immutable releases: FAILED → a published release will be able to have its assets REPLACED."
  echo "    The pin from §13 becomes bypassable without touching the tag. Enable in the UI:"
  echo "    Settings → Releases → Enable release immutability (NOT retroactive: before v1)."
fi

# 3c. GITHUB_TOKEN READ-ONLY by default (OpenSSF "Token-Permissions" check).
#     All our workflows already declare their `permissions:` block — so the gain isn't immediate.
#     It's a safety net for the FUTURE workflow that forgets to do it: without this default, it
#     inherits a write token. Free, and the default is only restrictive for repos created
#     after February 2023 — so it's set explicitly rather than assumed.
mutate gh api -X PUT "repos/$SLUG/actions/permissions/workflow" \
  -f 'default_workflow_permissions=read' \
  -F 'can_approve_pull_request_reviews=false' >/dev/null 2>&1 \
  && echo "  ✓ GITHUB_TOKEN default = read (a workflow with no 'permissions:' block no longer inherits a write token)" \
  || echo "  ⚠ default_workflow_permissions: failed — check Settings > Actions > General."

# 4. CodeQL: ENABLED BY THIS SCRIPT, in DEFAULT SETUP (see the "═══ CodeQL" block further below).

# 5. GitHub Pages — CREATE the site, source = GitHub Actions.
#    ⚠ `enablement: true` in actions/configure-pages is NOT ENOUGH: creating a Pages site requires
#      Administration, which a workflow's GITHUB_TOKEN doesn't have → "Resource not accessible by
#      integration", on EVERY deploy, as long as the site doesn't exist. It's therefore a one-shot
#      admin action, and its place is here.
#    Triggered automatically if the repo has a pages.yml: nothing to remember, no flag to pass.
# ⚠ On a PRIVATE repo, GET /contents requires "Contents: read". Without it, the call fails and the
#   entire Pages block (homepage included) would be skipped SILENTLY. So the 3 cases are told apart:
#   workflow present / absent / unreadable. (On a public repo, the contents API is open.)
PAGES_WF=$(gh api "repos/$SLUG/contents/.github/workflows/pages.yml" --jq '.name' 2>/dev/null || true)
if [ -z "$PAGES_WF" ] && [ "$(gh api "repos/$SLUG" --jq '.private')" = "true" ]; then
  echo "  ↳ pages.yml not readable — if this repo has one, the admin PAT is missing \"Contents: read\"."
fi
if [ "$PAGES_WF" = "pages.yml" ]; then
  if gh api "repos/$SLUG/pages" >/dev/null 2>&1; then
    mutate gh api -X PUT "repos/$SLUG/pages" -f 'build_type=workflow' >/dev/null 2>&1 \
      && echo "  ✓ Pages: already created, source confirmed = GitHub Actions" \
      || echo "  ⚠ Pages: site exists, source not modifiable — check Settings → Pages"
  # 3rd call gated on VISIBILITY (after secret scanning and PVR): Pages is unavailable on a
  # private Free repo. Same dry-run guard — without it, `mutate` succeeds and the script would
  # announce a site "created" where it can't exist. (The "already created" branch above does NOT
  # need it: the READ having succeeded proves this repo can carry Pages.)
  else
    PAGES_OK=0
    mutate gh api -X POST "repos/$SLUG/pages" -f 'build_type=workflow' >/dev/null 2>&1 || PAGES_OK=1
    if [ "$DRY" -eq 1 ] && [ "$IS_PRIVATE" = "true" ]; then PAGES_OK=1; fi
    if [ "$PAGES_OK" -eq 0 ]; then
      echo "  ✓ Pages: site created, source = GitHub Actions"
    # DO NOT blame the failure on visibility without reading it: the real cause
    # here was the admin PAT missing "Pages: write" — a permission DISTINCT from Administration.
    elif [ "$IS_PRIVATE" = "true" ]; then
      echo "  ⚠ Pages: unavailable on a PRIVATE repo on the Free plan → will be created on the flip to public."
    else
      echo "  ⚠ Pages: creation refused on a PUBLIC repo → the admin PAT is missing \"Pages: write\""
      echo "    (a permission DISTINCT from Administration). Add it and rerun."
    fi
  fi

  # The homepage feeds the "documentation" item of the community profile: without it, the
  # PUBLIC score caps at 87% (the item doesn't even exist on a private repo).
  # It's derived from the Pages site just created: the loop closes on its own.
  if [ -z "$HOMEPAGE" ]; then
    PAGES_URL=$(gh api "repos/$SLUG/pages" --jq '.html_url' 2>/dev/null || true)
    case "$PAGES_URL" in
      https://*) mutate gh repo edit "$SLUG" --homepage "$PAGES_URL" >/dev/null 2>&1 \
                   && echo "  ✓ homepage = $PAGES_URL  (→ \"documentation\" item of the community profile)" ;;
    esac
  fi
fi

# 6. Ruleset 'main' — idempotent: update if a ruleset of the same name exists, else create.
#    Robust minimum: PR required (0 review, squash), no force-push/delete, CI required.
#    ✅ REPLAYABLE WITHOUT DAMAGE: rules added by hand
#       (code_quality…) are PRESERVED on merge. Previously, a bare PUT
#       replaced the whole ruleset and wiped them out silently.
RULESET_NAME="main"

# CodeQL as a REQUIRED check (standard §17). Impossible on a brand-new repo — CodeQL has never run,
# requiring it would block EVERY PR. So it's set as soon as the 1st analysis exists, instead of
# deferring it to a manual step "for later" — which means never.
#
# ⚠ NEVER confuse "0 analyses" with "not allowed to look". The admin PAT does NOT have
#   "Code scanning alerts: read" by default: the call then returns 403, and reading that as
#   "CodeQL has never run" SILENTLY skips the check.
# Checks REQUIRED before merge. `build-check` (ARTEFACT capability) validates the Dockerfile AND
# scans the image (Trivy, CRITICAL/HIGH). If it isn't REQUIRED, the scan is DECORATIVE: a PR
# carrying a critical CVE would still pass. Detected from the workflow's presence — nothing to remember.
CHECKS_JSON='[ { "context": "checks" } ]'
if gh api "repos/$SLUG/contents/.github/workflows/docker-publish.yml" >/dev/null 2>&1; then
  CHECKS_JSON='[ { "context": "checks" }, { "context": "build-check" } ]'
  echo "  ↳ ARTEFACT capability detected (docker-publish.yml) → 'build-check' (Dockerfile + Trivy scan) becomes a REQUIRED check."
fi

# 🔴 The rulesets API accepts ANY string as a required context — including one no job will ever
# produce. Every PR then sits on "Expected — waiting for status" forever, the PR that would add the
# job included. So each context is verified against the workflows of the DEFAULT BRANCH: the SERVER,
# not the working tree — this script takes a slug and runs without a checkout.
# ⚠ Ceiling, NOT caught here: a job carrying `name:` or a `matrix` reports under a DIFFERENT
#   check-run name, and a workflow with no `pull_request` trigger never reports on a PR at all.
job_declared() {
  local wf body
  for wf in $(gh api "repos/$SLUG/contents/.github/workflows" --jq '.[].name' 2>/dev/null); do
    # Command substitution, never a pipe into grep: under `pipefail`, `grep -q` closing the pipe
    # early SIGPIPEs `gh api` and the pipeline reports failure on a MATCH.
    body=$(gh api "repos/$SLUG/contents/.github/workflows/$wf" \
             -H 'Accept: application/vnd.github.raw' 2>/dev/null || true)
    # Anchored on "nothing after the colon": `permissions:` also carries a 2-space `checks: write`.
    grep -qE "^  $1:[[:space:]]*(#.*)?$" <<<"$body" && return 0
  done
  return 1
}
MISSING=""
for CTX in $(printf '%s' "$CHECKS_JSON" | jq -r '.[].context'); do
  job_declared "$CTX" || MISSING="$MISSING '$CTX'"
done
if [ -n "$MISSING" ]; then
  echo "  ✗ NO job named$MISSING in .github/workflows on the default branch of $SLUG."
  echo "    Requiring it would LOCK the repo — add a job under that EXACT name first (RUNBOOK §5)."
  # In dry-run the script keeps going: its whole point is to surface this BEFORE the real run.
  [ "$DRY" -eq 1 ] || exit 1
fi

# ═══ CodeQL: the native DEFAULT SETUP, and NO LONGER a committed `codeql.yml` ═══════════════════
# The default setup DETECTS languages and UPDATES ITSELF as the repo changes, scheduled scans
# included. The WHY, sources, and where the advanced setup would be justified:
# standard §17. (The check-run keeps the name "CodeQL": the ruleset rule below is
# unchanged.)
# ⚠ `gh api` writes the error's JSON body to STDOUT, not stderr. A naive
#   `DS=$(gh api … || echo unreadable)` therefore produces "{"message":"403…"}unreadable" — a string
#   equal to NOTHING, and every test that follows goes down the wrong branch, silently.
#   The SAME trap already fixed for rulesets (see further below). So a JSON that actually carries
#   `.state` is REQUIRED before believing what's read.
DS_RAW=$(gh api "repos/$SLUG/code-scanning/default-setup" 2>/dev/null || true)
if printf '%s' "$DS_RAW" | jq -e 'has("state")' >/dev/null 2>&1; then
  DS_STATE=$(printf '%s' "$DS_RAW" | jq -r '.state')
else
  DS_STATE=unreadable
fi
if [ "$DS_STATE" = "configured" ]; then
  echo "  ✓ CodeQL default setup already active — languages detected and KEPT UP TO DATE by GitHub."
elif [ "$DS_STATE" = "unreadable" ] && [ "$IS_PRIVATE" = "false" ]; then
  # DO NOT guess. On a PUBLIC repo, this endpoint MUST respond: if it doesn't, it's the
  # PAT missing `Administration` — and without this guard the script would go on to a PATCH that
  # also fails, wrongly blaming "the default setup wasn't configured".
  echo "  ⚠ CodeQL default setup state UNREADABLE on a PUBLIC repo → the PAT is missing 'Administration'."
  echo "    CodeQL will be NEITHER enabled NOR checked. Fix the PAT, then REPLAY."
else
  # A committed `codeql.yml` (a repo from BEFORE this change) will be DISABLED by the switch.
  # SAY IT, never silently: a file in the repo stops running, and an orphaned workflow
  # sitting around is a check nobody reads anymore.
  if gh api "repos/$SLUG/contents/.github/workflows/codeql.yml" >/dev/null 2>&1; then
    echo "  ⚠ this repo carries a committed 'codeql.yml' → the switch flips it to 'disabled_manually'."
    echo "    This is INTENTIONAL: the default setup covers MORE languages, and GitHub keeps them up to date."
    echo "    → The file becomes DEAD: REMOVE it via a PR."
  fi
  # ⚠ THE ONLY WRITE IN THIS SCRIPT THAT DOES NOT GO THROUGH `mutate()` — and it matters to know why.
  #   `mutate()` exists only to intercept; it does NOT RETURN the command's output. Yet the
  #   `run_id` returned by the PATCH is needed here. So the dry-run guard is kept BY HAND.
  #   🔴 The "ONE SINGLE interception point" invariant (see `mutate`) is therefore FALSE RIGHT HERE:
  #      the dry-run's safety hinges on this `if`, and on it alone. Any future edit that moved
  #      the PATCH out of the `else` branch would WRITE FOR REAL, silently, on a live repo.
  if [ "$DRY" -eq 1 ]; then
    mutate gh api -X PATCH "repos/$SLUG/code-scanning/default-setup" -f state=configured
    # ⚠ DRY-RUN MUST NOT LIE — it announces what WOULD happen, not what's hoped for.
    #   It used to say "✓ ENABLED" EVEN ON A PRIVATE REPO, where the PATCH is bound to fail (Advanced
    #   Security required): the script contradicted itself TWO LINES DOWN ("CodeQL unavailable in
    #   private"). A dry-run promising an impossible setting is worse than a silent dry-run: it gets
    #   believed.
    if [ "$IS_PRIVATE" = "true" ]; then
      echo "  ↳ CodeQL: the PATCH WILL FAIL — unavailable on a PRIVATE repo (Advanced Security required)."
      echo "    EXPECTED. CodeQL will activate on the NEXT RUN of this script AFTER the flip to public (§4)."
    else
      echo "  ✓ CodeQL default setup ENABLED (languages auto-detected)."
    fi
  else
    DS_RUN=$(gh_val '.run_id' '' -X PATCH "repos/$SLUG/code-scanning/default-setup" -f state=configured)
    # BELT AND SUSPENDERS: a run_id is an INTEGER. Everything else — error body, empty string,
    # `null` — means the activation FAILED. Without this filter, an error JSON passed for a
    # run_id, the script announced "✓ ENABLED" on a repo where CodeQL is unavailable, and the two
    # branches below (private / public failure) became UNREACHABLE.
    case "$DS_RUN" in ''|*[!0-9]*) DS_RUN="" ;; esac
    if [ -n "$DS_RUN" ]; then
      echo "  ✓ CodeQL default setup ENABLED — 1st analysis launched (run $DS_RUN)."
      # 🔴 WAITING — this is NOT a nicety. The 'code_scanning' rule is only set further below IF
      #    an analysis EXISTS. Without this wait, the script would have JUST ENABLED CodeQL, read
      #    "0 analyses", and NOT SET the rule: `main` would stay UNPROTECTED until
      #    someone thinks to rerun the script. A security hole opened BY THE SCRIPT ITSELF.
      # ⚠ The loop MUST tell "not finished yet" apart from "not allowed to look".
      #   Since `gh api` writes its errors to STDOUT, a plain `= "completed"` NEVER sees the
      #   difference: on a 403 it would spin 36 × 10s = SIX MINUTES, silently, only to
      #   continue without knowing. So the status is tested AGAINST THE LIST of valid values.
      printf '    … waiting for the 1st analysis — without it, the rule would not be set '
      DS_DONE=0; DS_BLIND=0
      for _ in $(seq 1 36); do
        RS=$(gh_val '.status' '' "repos/$SLUG/actions/runs/$DS_RUN")
        case "$RS" in
          completed) DS_DONE=1; break ;;
          queued|in_progress|requested|waiting|pending) DS_BLIND=0; printf '.'; sleep 10 ;;
          # ⚠ DO NOT conclude on the 1st miss. GitHub takes a few seconds to MATERIALIZE the run: a
          #   transient 404 (or a rate-limit) is NORMAL at the start. Concluding immediately "the PAT
          #   is missing Actions:read" would be a WRONG DIAGNOSIS — the very defect this file spends
          #   its time chasing: accusing the PAT of a permission it actually has. 3 CONSECUTIVE
          #   unreadable responses are tolerated before deciding.
          *) DS_BLIND=$((DS_BLIND + 1))
             if [ "$DS_BLIND" -ge 3 ]; then
               echo
               echo "  ⚠ CodeQL run UNREADABLE (3 times in a row) → the admin PAT is missing \"Actions: read\"."
               echo "    Without it, there's no way to know when the analysis finishes: the"
               echo "    'code_scanning' rule risks NOT being set, and 'main' staying UNGUARDED."
               echo "    → Add the permission to the PAT, then REPLAY."
               break
             fi
             printf '?'; sleep 10 ;;
        esac
      done
      [ "$DS_DONE" -eq 1 ] && echo " ok" || echo
    elif [ "$IS_PRIVATE" = "true" ]; then
      echo "  ↳ CodeQL unavailable on this PRIVATE repo (Advanced Security required) — EXPECTED, not a failure."
      echo "    It will activate on the NEXT RUN of this script AFTER the flip to public (§4). The PAT is NOT at fault."
    else
      echo "  ⚠ default setup activation FAILED on a PUBLIC repo → CodeQL IS NOT RUNNING."
      echo "    Does the PAT really carry 'Administration: write'? Fix it, then REPLAY."
    fi
  fi
fi

# THREE distinct cases, NEVER to confuse:
#   · JSON list           → CodeQL has run: we know how many analyses exist.
#   · 404 "no analysis found" → the endpoint RESPONDS, there is simply NO analysis yet.
#   · 403 / other          → we are NOT allowed to look (permission or plan).
# Treating the 404 as a 403 accuses the PAT of a permission it actually has — and sends the
# human off looking for a right that's already there.
CS_BODY=$(gh api "repos/$SLUG/code-scanning/analyses" 2>&1 || true)
if printf '%s' "$CS_BODY" | jq -e 'type == "array"' >/dev/null 2>&1; then
  ANALYSES=$(printf '%s' "$CS_BODY" | jq 'length')
  CS_READABLE=1
elif printf '%s' "$CS_BODY" | grep -q "no analysis found"; then
  ANALYSES=0          # the endpoint responds: there's just nothing there yet
  CS_READABLE=1
else
  ANALYSES=0
  CS_READABLE=0       # 403: missing right, or feature unavailable on this plan
fi
read -r -d '' RULESET_JSON <<JSON || true
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
    } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": false,
        "required_status_checks": $CHECKS_JSON
    } }
  ]
}
JSON

# code_scanning rule: added ONLY if CodeQL has already produced an analysis.
CS_RULE='{"type":"code_scanning","parameters":{"code_scanning_tools":[
  {"tool":"CodeQL","security_alerts_threshold":"high_or_higher","alerts_threshold":"errors"}]}}'
if [ "$CS_READABLE" -eq 0 ] && [ "$IS_PRIVATE" = "true" ]; then
  echo "  ↳ CodeQL unavailable while private (Advanced Security required) → 'code_scanning' rule not set."
  echo "    EXPECTED. It will be set on the flip to public, as soon as the 1st analysis exists. The PAT is NOT at fault."
elif [ "$CS_READABLE" -eq 0 ]; then
  echo "  ⚠ CodeQL analyses UNREADABLE on a PUBLIC repo → the admin PAT is missing \"Code scanning alerts: read\"."
  echo "    The 'code_scanning' rule is therefore NOT set: CodeQL will NOT block PRs."
  echo "    → Add this permission (read-only) to the PAT and REPLAY."
elif [ "$ANALYSES" -gt 0 ]; then
  RULESET_JSON=$(printf '%s' "$RULESET_JSON" | jq -c --argjson r "$CS_RULE" '.rules += [$r]')
  echo "  ↳ CodeQL produced $ANALYSES analysis(es) → 'code_scanning' rule set: an alert blocks the PR."
else
  # This case should NO LONGER happen on a public repo: the script has just enabled the default
  # setup AND waited for its 1st analysis. Landing here means the ANALYSIS FAILED — it's
  # therefore not "not yet", it's "not working", and it should be said that way.
  echo "  ⚠ NO CodeQL analysis despite activation → the 'code_scanning' rule is NOT set."
  echo "    'main' is therefore NOT guarded by CodeQL. Check the 'CodeQL Setup' run in Actions,"
  echo "    then REPLAY this script once the analysis is green."
fi

# ⚠ On an HTTP error (403 "Upgrade to GitHub Pro" on a PRIVATE Free repo), `gh api`
# writes the error's JSON body to STDOUT. Without this guard, that JSON was swallowed as if
# it were a ruleset ID, then pasted back into the PUT's URL → an unintelligible error.
# So a REAL JSON list is required before going any further.
RULESETS=$(gh api "repos/$SLUG/rulesets" 2>/dev/null || true)
if ! printf '%s' "$RULESETS" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "  ⚠ rulesets UNAVAILABLE on this repo — expected on a PRIVATE repo on the Free plan (standard §18)."
  echo "    'main' is therefore NOT protected: no PR required, no required checks, force-push possible."
  echo "    TAGS aren't protected either → the prod version pin (§13) guarantees nothing."
  echo "    → REPLAY this script on the flip to public (full procedure: standard §18)."
  RULESETS=""
fi

# upsert_ruleset <name> <json> — create if absent, update otherwise. IDEMPOTENT.
#   · Rules of a type THIS ruleset doesn't manage (e.g. `code_quality` set by hand, or
#     `code_scanning` when CodeQL hasn't run yet) are PRESERVED: the managed scope is
#     derived from the types present in the supplied JSON, not from a fixed list that would drift.
#   · DEDUPLICATED merge by type → no duplicates on replay.
#   · bypass_actors: never removed silently (the standard wants none, but it's up to
#     the human to decide).
upsert_ruleset() {
  RS_NAME="$1"; RS_JSON="$2"
  [ -n "$RULESETS" ] || return 0

  RS_ID=$(printf '%s' "$RULESETS" | jq -r --arg n "$RS_NAME" '.[] | select(.name==$n) | .id' | head -n1)
  case "$RS_ID" in (''|*[!0-9]*) RS_ID="" ;; esac   # only proceed with a numeric ID

  if [ -z "$RS_ID" ]; then
    printf '%s' "$RS_JSON" | mutate gh api -X POST "repos/$SLUG/rulesets" --input - >/dev/null \
      && echo "  ✓ ruleset '$RS_NAME' created" \
      || echo "  ⚠ ruleset '$RS_NAME': creation refused"
    return 0
  fi

  RS_CUR=$(gh api "repos/$SLUG/rulesets/$RS_ID")
  RS_KEPT=$(printf '%s' "$RS_CUR" | jq -c --argjson mine "$(printf '%s' "$RS_JSON" | jq -c '.rules')" \
            '[.rules[]? | select(.type as $t | ($mine | map(.type) | index($t)) | not)]')
  RS_NKEPT=$(printf '%s' "$RS_KEPT" | jq 'length')
  [ "$RS_NKEPT" -gt 0 ] && \
    echo "  ↳ '$RS_NAME': $RS_NKEPT rule(s) outside scope preserved: $(printf '%s' "$RS_KEPT" | jq -r '[.[].type] | join(", ")')"

  RS_NBYP=$(printf '%s' "$RS_CUR" | jq '[.bypass_actors[]?] | length')
  if [ "$RS_NBYP" -gt 0 ]; then
    echo "  ⚠ '$RS_NAME': $RS_NBYP bypass_actor(s) — the standard wants none."
    echo "    They will NOT be removed automatically. Remove them by hand if wanted."
    RS_JSON=$(printf '%s' "$RS_JSON" | jq -c --argjson b "$(printf '%s' "$RS_CUR" | jq -c '.bypass_actors')" '.bypass_actors = $b')
  fi

  printf '%s' "$RS_JSON" | jq -c --argjson kept "$RS_KEPT" '.rules += $kept' \
    | mutate gh api -X PUT "repos/$SLUG/rulesets/$RS_ID" --input - >/dev/null \
    && echo "  ✓ ruleset '$RS_NAME' updated (#$RS_ID) — script's rules applied, the rest untouched"
}

# ⚠ SQUASH-ONLY and a STAGING branch are INCOMPATIBLE.
#   Squashing `develop` into `main` rewrites the commits: the two branches then diverge on EVERY
#   cycle (same changes, different SHAs), and the `feat/*` history is lost.
#   → If `develop` exists, `main` ALSO accepts merge commits (that's what §12 prescribes for
#     the staging → prod promotion). `develop` itself stays squash-only: `feat/*` branches get
#     squashed into a single clean commit there.

# ⚠️ PROMOTING TO PROD DESTROYS STAGING — and the script used to be its silent victim.
#   `delete_branch_on_merge` (set above, useful for `feat/*` branches) deletes the SOURCE branch
#   of EVERY merged PR — so `develop` itself, when the `develop → main` PR from §12 gets merged.
#   In PUBLIC, the 'develop' ruleset (the `deletion` rule) prevents this. In PRIVATE, there is NO
#   ruleset at all: the 1st production deploy DELETES the staging branch, without a word.
#
#   The script used to infer staging from `develop`'s EXISTENCE. Once gone, it concluded "no
#   staging" and aligned everything on that: no 'develop' ruleset, and `main` FELL BACK to squash-only
#   — making the next promotion IMPOSSIBLE. A cascading failure, triggered by success.
#
#   → So the branch's mere existence is no longer trusted: the repo is ALSO asked what it
#     PUBLISHES (`WANTS_STAGING`, probed up front alongside `HAS_DEVELOP`).
if [ "$WANTS_STAGING" -eq 1 ] && [ "$HAS_DEVELOP" -eq 0 ]; then
  echo "  ⚠ INCONSISTENCY — the repo PUBLISHES a THREE-stage flow, but the 'develop' branch DOES NOT EXIST."
  echo "    Near-certain cause: 'delete-branch-on-merge' DELETED it on the merge of the develop → main PR."
  echo "    In PRIVATE, no ruleset protects it: putting into production DESTROYS staging."
  echo "    Without it: no 'develop' ruleset, and 'main' falls back to SQUASH-ONLY — so the"
  echo "    next promotion becomes IMPOSSIBLE (squashing develop into main makes them diverge, §12)."
  echo "    → RECREATE IT, THEN REPLAY THIS SCRIPT:"
  echo "        git switch -c develop main && git push -u origin develop"
  echo "      The 'develop' ruleset ('deletion' rule) will then prevent it from being deleted again."
fi

# ⚠️ THE SAME SETTING, BUT TAKEN UPSTREAM — because WARNING WASN'T ENOUGH.
#   The block above only speaks AFTER the damage, and only if this script is replayed. Yet the
#   loss is CERTAIN and AUTOMATIC: `delete_branch_on_merge` targets the SOURCE branch of the PR, and
#   the source of a §12 promotion IS `develop`. What saves it in PUBLIC is the ruleset (its
#   `deletion` rule: GitHub never deletes a protected branch, even with the option enabled). In
#   PRIVATE Free there is NO ruleset at all — so no safety net, and warning isn't enough.
#   → So here the setting is REMOVED. What's lost is automatic cleanup of `feat/*` branches — a
#     convenience, one click — against a long-lived branch destroyed silently, which breaks the
#     NEXT promotion (without `develop`, this script concludes "no staging" and `main` falls back to
#     squash-only). Flipping to public restores it: replay this script, the ruleset takes over.
# Dependabot security updates: its PRs ALWAYS target the default branch — on three stages they
# would bypass staging. §3a no longer sets them here; this block REMOVES the PRIOR state
# (a repo configured before this change, or enabled by hand), and only if Renovate is PROVEN
# alive. The why and the threshold: standard, "Who updates dependencies".
#   ⚠ FRESHNESS, not existence: an opted-out repo keeps its Dependency Dashboard intact.
#     Probing `.updated_at` is the only signal that tells a running bot apart from a dead one.
if [ "$HAS_DEVELOP" -eq 1 ] || [ "$WANTS_STAGING" -eq 1 ]; then
  DASH_RC=0
  DASH_AT=$(gh api "repos/$SLUG/issues?state=open&per_page=100" \
    --jq 'map(select(.title=="Dependency Dashboard"))|.[0].updated_at // empty' 2>/dev/null) || DASH_RC=$?
  # ⚠ `gh api` writes its error JSON to STDOUT: without this SHAPE filter, a `{"message":"Not Found"}`
  #   compared to an ISO date is judged MORE RECENT (`{` > `2` in ASCII) — a read failure would REMOVE
  #   the safety net. Measured: that's what an empty `$SLUG` returns.
  #   The exit code is kept SEPARATELY: without it, "refused" and "absent" look alike, and a
  #   missing permission would send the maintainer looking toward Renovate — the silent failure this forbids.
  case "$DASH_AT" in 20[0-9][0-9]-*) ;; *) DASH_AT="" ;; esac
  # `date -v` (BSD/macOS) then `date -d` (GNU): the script runs on both.
  FRESH=$(date -u -v-14d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ)
  if [ -n "$DASH_AT" ] && [[ "$DASH_AT" > "$FRESH" ]]; then
    mutate gh api -X DELETE "repos/$SLUG/automated-security-fixes" >/dev/null 2>&1 \
      && echo "  ✓ Dependabot security updates REMOVED — 3 stages, Renovate alive (dashboard $DASH_AT)" \
      || echo "  ⚠ DELETE automated-security-fixes: failed — check Settings → Advanced Security."
  else
    echo "  ⚠ Dependabot security updates KEPT — 3 stages, but Renovate NOT proven alive."
    echo "    Its security PRs will target 'main', bypassing 'develop'. Cause and action:"
    if [ "$DASH_RC" -ne 0 ]; then
      echo "    → READ REFUSED (issues unreadable). The admin PAT is missing 'Issues: Read' — the"
      echo "      full recipe is in docs/RUNBOOK.md. Fix it, then REPLAY."
    elif [ -z "$DASH_AT" ]; then
      echo "    → NO 'Dependency Dashboard': the Renovate app isn't installed on this repo."
      echo "      Install it (GitHub UI), wait for its 1st run, then REPLAY."
    else
      echo "    → Dashboard STALE ($DASH_AT, threshold $FRESH): Renovate is installed but no longer running."
      echo "      Check that no onboarding PR was closed (the bot's documented opt-out)."
    fi
  fi
fi

if { [ "$WANTS_STAGING" -eq 1 ] || [ "$HAS_DEVELOP" -eq 1 ]; } && [ -z "$RULESETS" ]; then
  mutate gh repo edit "$SLUG" --delete-branch-on-merge=false
  echo "  ⚠ 'delete-branch-on-merge' REMOVED — 3-stage flow WITHOUT a ruleset (private Free): it"
  echo "    would delete 'develop' on the 1st promotion. 'feat/*' branches must be deleted by hand."
  echo "    On the flip to PUBLIC, replay this script: the 'develop' ruleset protects, it gets restored."
fi

if [ "$HAS_DEVELOP" -eq 1 ]; then
  RULESET_JSON=$(printf '%s' "$RULESET_JSON" | jq -c \
    '(.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods) = ["squash","merge"]')
  mutate gh repo edit "$SLUG" --enable-merge-commit >/dev/null 2>&1 \
    && echo "  ↳ 'develop' exists → 'main' ALSO accepts merge commits (staging → prod promotion, §12)."
fi

upsert_ruleset "$RULESET_NAME" "$RULESET_JSON"

# 6b. Ruleset 'develop' — ONLY if the branch exists (STAGING capability, standard §12).
if [ -n "$RULESETS" ] && gh api "repos/$SLUG/branches/develop" >/dev/null 2>&1; then
  DEV_JSON=$(printf '%s' "$RULESET_JSON" | jq -c \
    '.name = "develop"
     | .conditions.ref_name.include = ["refs/heads/develop"]
     | .rules = [ .rules[] | select(.type != "code_scanning") ]
     | (.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods) = ["squash"]')
  upsert_ruleset "develop" "$DEV_JSON"
fi

# 6c. TAGS ruleset — THIS is the control that makes the §13 version pin real.
#     Without it, a `v1.2.3` tag can be MOVED or DELETED: prod pins `APP_IMAGE_TAG=1.2.3`
#     believing it freezes an artifact, while the tag could point elsewhere tomorrow. The pin only
#     holds if the tag is immutable.
read -r -d '' TAGS_JSON <<'JSON' || true
{
  "name": "tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [ { "type": "deletion" }, { "type": "update" }, { "type": "non_fast_forward" } ]
}
JSON
upsert_ruleset "tags" "$TAGS_JSON"

# 6c. *CLASSIC* BRANCH PROTECTION — the OTHER system, which `GET /rulesets` DOES NOT SHOW.
#     An existing repo may carry one, inherited, requiring checks named after ITS old
#     jobs. Adopting the template's workflows makes those checks STOP EXISTING: the rule survives and
#     forever demands a status nothing will ever produce again — the branch is LOCKED, CI
#     green or not, and `gh pr merge` only answers "base branch policy prohibits the merge".
#     The two systems STACK: setting the ruleset does not neutralize the old rule.
# ⚠ This DETECTS and REPORTS — it does not delete: the classic rule may carry settings the
#   ruleset doesn't replicate, and destroying a protection is a decision for the maintainer (like visibility).
for BR in main develop; do
  gh api "repos/$SLUG/branches/$BR/protection" >/dev/null 2>&1 || continue
  CTX=$(gh api "repos/$SLUG/branches/$BR/protection" \
          --jq '[.required_status_checks.contexts[]?] | join(", ")' 2>/dev/null || true)
  echo "  ⚠ CLASSIC branch protection still active on '$BR'${CTX:+ — required checks: $CTX}."
  echo "    It STACKS with the ruleset just set. If it requires a check that's GONE"
  echo "    (jobs renamed while adopting the template's workflows), NO PR will EVER pass."
  echo "    → remove it now that the ruleset protects: https://github.com/$SLUG/settings/branches"
done

# 7. FINAL CHECK — community profile.
#    The score is the only indicator for settings the API does NOT expose ("Reported content":
#    neither REST nor GraphQL). Without this check,
#    a missing item stays invisible: the script would say "everything is applied" and it would be false.
PROFILE=$(gh api "repos/$SLUG/community/profile" 2>/dev/null || true)
if printf '%s' "$PROFILE" | jq -e '.health_percentage' >/dev/null 2>&1; then
  HEALTH=$(printf '%s' "$PROFILE" | jq '.health_percentage')
  # `issue_template` is ALWAYS null when the templates are in a folder (an API artifact,
  # with no effect on the score) → exclude it, otherwise a missing item is reported that doesn't exist.
  MISSING=$(printf '%s' "$PROFILE" | jq -r '[.files | to_entries[]
              | select(.value == null)
              | select(.key | IN("issue_template","code_of_conduct_file") | not) | .key]
              + (if .description == null then ["description"] else [] end)
              + (if .documentation == null then ["documentation (homepage)"] else [] end)
              | join(", ")')
  if [ "$HEALTH" -ge 100 ]; then
    echo "  ✓ community profile: 100%"
  else
    echo "  ⚠ community profile: $HEALTH% — incomplete."
    [ -n "$MISSING" ] && echo "    Missing files/fields: $MISSING"
    if [ -z "$MISSING" ]; then
      # All files are there but the score isn't full → it's the UI-only item, which
      # exists ONLY on ORGANIZATION repos (8-item checklist instead of 7).
      echo "    All files are present → what's left is the NON-SCRIPTABLE item:"
      echo "    Settings > Moderation options > Reported content > 'Prior contributors and collaborators'"
      echo "    https://github.com/$SLUG/settings/moderation/reported-content"
      echo "    (No API, neither REST nor GraphQL. GitHub's default does NOT apply to a repo"
      echo "     created PRIVATE then flipped public — exactly our case.)"
    fi
  fi
fi

echo "✓ $SLUG: server settings applied."
echo
echo "  ⚠️  REVOKE THE ADMIN PAT NOW — it no longer has any reason to exist:"
echo "     https://github.com/settings/personal-access-tokens"
echo
if gh api "repos/$SLUG/contents/.github/workflows/docker-publish.yml" >/dev/null 2>&1; then
# VERIFY instead of REMINDING. A GREEN "Publish image" job does NOT prove the image is
# pullable. This test queries the registry EXACTLY like the prod host does:
# anonymously, with no token at all. It's the only proof that counts.
# (The packages API is out of reach: fine-grained PATs do NOT support ghcr — classic only.)
# THREE states, not two. A `PULL_OK` boolean used to conflate "tested and FAILED" with "NOT TESTABLE",
# and would therefore demand making public a package THAT DOESN'T EXIST YET — on a brand-new repo, with
# no release at all. Demanding an action on a nonexistent object is the BUG 4 defect RECURRING:
# TALKING WITHOUT KNOWING. And the noise has a cost: it ends up drowning out the reminder to REVOKE THE ADMIN PAT.
PULL_STATE=untested
if [ "$IS_PRIVATE" = "false" ] && [ "$(gh_val 'length' 0 "repos/$SLUG/releases")" -gt 0 ]; then
  TAG=$(gh api "repos/$SLUG/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//')
  # The ghcr package name is NOT derivable from the slug. It happens to match on a GENERATED project
  # (init-project.sh substitutes `<image-name>` with the repo's name) — hence a bug long invisible.
  # A MIGRATED repo publishes under whatever name it wants (`<Repo>` → `<repo>-collector`): deriving it
  # made the script test a NONEXISTENT package, therefore announce "image NOT PULLABLE, the prod pin is
  # worthless" and demand making public an object that doesn't exist. The source of truth — the
  # workflow's `images:` — is READ instead, falling back to the slug if unreadable (a strictly additive fix).
  # `Accept: raw` avoids a base64 decode (`-d` GNU vs `-D` BSD aren't portable).
  IMG_NAME=$(gh api -H "Accept: application/vnd.github.raw" \
      "repos/$SLUG/contents/.github/workflows/docker-publish.yml" 2>/dev/null \
    | sed -n 's|^[[:space:]]*images:[[:space:]]*ghcr\.io/[^/]*/\([A-Za-z0-9._-][A-Za-z0-9._-]*\).*|\1|p' \
    | head -1)
  # ghcr accepts ONLY lowercase: `<owner>/<Repo>` queries a path that doesn't exist.
  IMG=$(printf '%s/%s' "${SLUG%%/*}" "${IMG_NAME:-${SLUG##*/}}" | tr '[:upper:]' '[:lower:]')
  ATOK=$(curl -s "https://ghcr.io/token?scope=repository:${IMG}:pull&service=ghcr.io" \
    | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
  ACODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${ATOK}" \
    -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/${IMG}/manifests/${TAG}" 2>/dev/null || echo 000)
  if [ "$ACODE" = "200" ]; then
    PULL_STATE=ok
    echo "  ✓ ghcr image PULLABLE anonymously (${IMG}:${TAG}) — the prod host can pull it."
  else
    PULL_STATE=ko
    echo "  ⚠ ghcr image NOT PULLABLE anonymously (${IMG}:${TAG} → HTTP ${ACODE})."
    echo "    The PROD host CANNOT pull it: the §13 version pin is WORTHLESS."
    echo "    Near-certain cause: the ghcr package is PRIVATE."
  fi
fi
# NO IMAGE YET: INFORM, demand NOTHING. The action, if needed, will be needed at the
# 1st release — and that's where the RUNBOOK §3 reminds of it, at the moment the object finally exists.
if [ "$PULL_STATE" = "untested" ]; then
  if [ "$IS_PRIVATE" = "true" ]; then
    echo "  ↳ PRIVATE repo: the ghcr package's visibility isn't relevant yet. It will be at the flip."
  else
    echo "  ↳ no release ⇒ NO ghcr image exists yet: nothing to make public today."
    echo "    At the 1st release, REPLAYING this script will test the anonymous pull and report it (RUNBOOK §3)."
  fi
fi
# ⚠️ The "make the package public" reminder is shown ONLY if the anonymous pull is NOT proven.
#   The default is NOT universal: on a PERSONAL account, a package published from a PUBLIC repo
#   inherits its access and is pullable IMMEDIATELY. On an ORG, it can be PRIVATE (org default).
#   → No more ASSUMING: it's TESTED, and only spoken about if it fails.
if [ "$PULL_STATE" = "ko" ]; then
  echo "  MANUAL ACTION NEEDED — ghcr package visibility (no API: fine-grained PATs do NOT"
  echo "  cover ghcr, only classic PATs do)."
  echo "     -> Package settings > Danger Zone > Change visibility > Public"
  # The packages URL DIFFERS by account type: /orgs/<o>/… for an organization,
  # /users/<o>/… for a personal account.
  OWNER_TYPE=$(gh_val '.type' 'Organization' "users/${SLUG%%/*}")
  if [ "$OWNER_TYPE" = "User" ]; then PKG_NS="users"; else PKG_NS="orgs"; fi
  # The package name comes from `images:` (see above), NEVER from the slug: `<Repo>` publishes
  # under `<repo>-collector`. Deriving it gave a 404 URL — right at the moment this
  # reminder matters most. `IMG` is in scope: PULL_STATE=ko is only set where it's computed.
  echo "     https://github.com/$PKG_NS/${SLUG%%/*}/packages/container/${IMG#*/}/settings"
  echo "     Without this action, the anonymous pull returns 403: neither the prod host nor a"
  echo "     user can pull the image."
  echo "     Org-wide: Settings > Packages > Package creation > default visibility."
fi
fi
