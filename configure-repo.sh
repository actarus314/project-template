#!/usr/bin/env bash
set -euo pipefail

# Server config for a repo (AGENTS.md: run by the maintainer, ephemeral admin PAT — recipe:
# docs/RUNBOOK.md step 7a; permission-to-endpoint map: docs/repo-controls.md, "Setup" table).
# One-shot, idempotent. --dry-run: diagnostics stay real GETs, only mutations are intercepted.
# Usage: ./configure-repo.sh <owner>/<repo> [homepage-url] [description] [topics-csv] [--dry-run]

DRY=0
ARGS=()   # array, not a rebuilt string — see docs/code/configure-repo.md
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

# Single interception point for every write (14 call sites) — why one, and the dry-run stdin
# trap it guards against: docs/code/configure-repo.md.
exec 3>&1   # copy of the real stdout: most calls end in `>/dev/null 2>&1`, which would hide the dry-run message
mutate() {
  if [ "$DRY" -eq 1 ]; then
    printf '  [dry-run] WOULD WRITE: %s\n' "$*" >&3
    [ -p /dev/stdin ] && cat >/dev/null 2>&1   # drain a piped call, else SIGPIPE kills the script (`-p`, not `-t`: see doc)
    return 0
  fi
  "$@"
}

# gh_val <jq-expr> <default> <gh api args…> — read a value, or return the default.
# 🔴 Never write `x=$(gh api … || echo default)`: `gh api` writes error JSON to STDOUT, so that
#   pattern silently produces a non-empty, non-matching string instead of the default — see
#   docs/code/configure-repo.md. Test the assignment's OWN exit code instead, and discard the output.
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

# Ephemeral admin PAT, entered by hand, never stored. `GH_TOKEN` from the environment is ignored
# on purpose (it's the write PAT); `ADMIN_PAT` is the only injection door — docs/code/configure-repo.md.
if [ -n "${ADMIN_PAT:-}" ]; then
  GH_TOKEN="$ADMIN_PAT"
else
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

# Read visibility BEFORE any diagnostic below: unreadable here, every downstream message would
# accuse the PAT instead of the plan (private/Free) — see docs/code/configure-repo.md.
IS_PRIVATE=$(gh api "repos/$SLUG" --jq '.private' 2>/dev/null || true)
if [ "$IS_PRIVATE" != "true" ] && [ "$IS_PRIVATE" != "false" ]; then
  echo "✗ Visibility of $SLUG unreadable — the PAT can't see the repo (wrong slug, expired PAT, or out of scope)."
  echo "  Stopping: without it, this script's diagnostics would accuse the wrong cause."
  exit 1
fi

# 1. Merge: squash only + delete branch on merge. Also the Administration preflight — the first
#    write in the script (docs/code/configure-repo.md).
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
# Description and topics require Administration:write (RUNBOOK.md step 7a) — only this script
# can set them. Control characters (a stray copy-paste artefact) make the API reject with 422;
# they're replaced (not deleted, which would glue words together) and the result echoed back —
# docs/code/configure-repo.md.
if [ -n "$DESCRIPTION" ]; then
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
if [ -n "$TOPICS" ]; then   # `--add-topic` adds, it does not overwrite what's there
  mutate gh repo edit "$SLUG" --add-topic "$TOPICS"
elif [ "$(gh_val '.names | length' 0 "repos/$SLUG/topics")" -eq 0 ]; then
  echo "  ⚠ no topics on the repo → it surfaces in NO GitHub search by subject."
  echo "    Set them: ./configure-repo.sh $SLUG '' '' 'topic-a,topic-b'"
fi
echo "  ✓ merge and delete-branch-on-merge (BOTH revisited below based on 'develop')${HOMEPAGE:+, homepage}${DESCRIPTION:+, description}${TOPICS:+, topics}"

# Discussions: `.github/ISSUE_TEMPLATE/config.yml` links every generated repo to `/discussions` —
# unset, that link 404s. Read back rather than trusted from the exit code: `has_discussions` isn't
# a documented PATCH body param, so an unknown-field 200 would enable nothing — docs/code/configure-repo.md.
mutate gh api -X PATCH "repos/$SLUG" -F has_discussions=true >/dev/null 2>&1 || true
if [ "$DRY" -eq 1 ] || [ "$(gh_val '.has_discussions' false "repos/$SLUG")" = "true" ]; then
  echo "  ✓ Discussions open (without them, the 'Question / Discussion' link in the issue template is a 404)"
else
  echo "  ⚠ Discussions STILL closed — the 'Question / Discussion' link in the issue template is a 404."
  echo "    Open them in the UI: https://github.com/$SLUG/settings → Features → Discussions"
fi

# 2. Security features (Administration).
SS_OK=0
mutate gh api -X PATCH "repos/$SLUG" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' \
  >/dev/null 2>&1 || SS_OK=1
# In dry-run `mutate` always "succeeds" — decide the verdict from visibility instead (repeated
# below for PVR and Pages): docs/code/configure-repo.md.
if [ "$DRY" -eq 1 ]; then
  [ "$IS_PRIVATE" = "true" ] && SS_OK=1 || SS_OK=0
fi
if [ "$SS_OK" -eq 0 ]; then
  echo "  ✓ secret scanning + push protection"
else
  echo "  ⚠ secret scanning / push protection: NOT enabled."
  echo "    Expected on a PRIVATE repo on the Free plan (unavailable — docs/repo-controls.md):"
  echo "    the gitleaks pre-commit hook is then the ONLY anti-secret safety net."
  echo "    → REPLAY this script when flipping to public."
fi

# Staging detected once, up front — §3a below needs it too. Two probes, because either alone can
# lie (docs/code/configure-repo.md): the branch's existence, and what CONTRIBUTING.md publishes.
HAS_DEVELOP=0
gh api "repos/$SLUG/branches/develop" >/dev/null 2>&1 && HAS_DEVELOP=1
WANTS_STAGING=0
gh api "repos/$SLUG/contents/CONTRIBUTING.md" --jq '.content' 2>/dev/null \
  | base64 -d 2>/dev/null | grep -q 'Three stages' && WANTS_STAGING=1

# 3. Dependabot alerts — CVE detection; Renovate reads it for its security PRs (repo-controls.md).
mutate gh api -X PUT "repos/$SLUG/vulnerability-alerts" >/dev/null 2>&1 \
  && echo "  ✓ Dependabot alerts (detection — Renovate reads these for its security PRs)" \
  || echo "  ⚠ vulnerability-alerts: failed — check in the UI"

# 3a. Dependabot security updates — safety net, 2-stage flows only (repo-controls.md:544 for the
#     dedicated-endpoint gotcha). Must follow vulnerability-alerts: nothing to remediate without detection.
if [ "$HAS_DEVELOP" -eq 0 ] && [ "$WANTS_STAGING" -eq 0 ]; then
  mutate gh api -X PUT "repos/$SLUG/automated-security-fixes" >/dev/null 2>&1 \
    && echo "  ✓ Dependabot security updates (safety net)" \
    || echo "  ⚠ automated-security-fixes: failed — check Settings → Advanced Security."
fi

# 3b. Private vulnerability reporting — public-only, without it SECURITY.md's link is dead
#     (repo-controls.md:512,538).
PVR_OK=0
mutate gh api -X PUT "repos/$SLUG/private-vulnerability-reporting" >/dev/null 2>&1 || PVR_OK=1
# `if`, not `[ a ] && [ b ] && x=1` on one line: that form returns 1 on a false test and `set -e` kills the script.
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

# 3d. Immutable releases — release-side counterpart of the 'tags' ruleset below, NOT retroactive,
#     set from private on rather than deferred to the flip (repo-controls.md:511,537 and
#     docs/code/configure-repo.md). PUT with no body → 204; GET returns { enabled, enforced_by_owner }.
if mutate gh api -X PUT "repos/$SLUG/immutable-releases" >/dev/null 2>&1; then
  echo "  ✓ immutable releases (a published release's assets can no longer be replaced)"
else
  echo "  ⚠ immutable releases: FAILED → a published release will be able to have its assets REPLACED."
  echo "    The version pin becomes bypassable without touching the tag. Enable in the UI:"
  echo "    Settings → Releases → Enable release immutability (NOT retroactive: before v1)."
fi

# 3c. GITHUB_TOKEN read-only by default — safety net for a future workflow with no `permissions:`
#     block (repo-controls.md:516); only restrictive by default on repos created after Feb 2023,
#     so set explicitly rather than assumed.
mutate gh api -X PUT "repos/$SLUG/actions/permissions/workflow" \
  -f 'default_workflow_permissions=read' \
  -F 'can_approve_pull_request_reviews=false' >/dev/null 2>&1 \
  && echo "  ✓ GITHUB_TOKEN default = read (a workflow with no 'permissions:' block no longer inherits a write token)" \
  || echo "  ⚠ default_workflow_permissions: failed — check Settings > Actions > General."

# 4. CodeQL: ENABLED BY THIS SCRIPT, in DEFAULT SETUP (see the "═══ CodeQL" block further below).

# 5. GitHub Pages — create the site (source = Actions); a workflow's GITHUB_TOKEN can't (needs
#    Administration). 3 cases told apart on purpose: workflow present / absent / unreadable
#    (Contents: read, private only) — docs/code/configure-repo.md.
PAGES_WF=$(gh api "repos/$SLUG/contents/.github/workflows/pages.yml" --jq '.name' 2>/dev/null || true)
if [ -z "$PAGES_WF" ] && [ "$IS_PRIVATE" = "true" ]; then
  echo "  ↳ pages.yml not readable — if this repo has one, the admin PAT is missing \"Contents: read\"."
fi
if [ "$PAGES_WF" = "pages.yml" ]; then
  if gh api "repos/$SLUG/pages" >/dev/null 2>&1; then
    mutate gh api -X PUT "repos/$SLUG/pages" -f 'build_type=workflow' >/dev/null 2>&1 \
      && echo "  ✓ Pages: already created, source confirmed = GitHub Actions" \
      || echo "  ⚠ Pages: site exists, source not modifiable — check Settings → Pages"
  else   # gated on visibility like §2/§3b: same dry-run guard, Pages unavailable on private Free
    PAGES_OK=0
    mutate gh api -X POST "repos/$SLUG/pages" -f 'build_type=workflow' >/dev/null 2>&1 || PAGES_OK=1
    if [ "$DRY" -eq 1 ] && [ "$IS_PRIVATE" = "true" ]; then PAGES_OK=1; fi
    if [ "$PAGES_OK" -eq 0 ]; then
      echo "  ✓ Pages: site created, source = GitHub Actions"
    elif [ "$IS_PRIVATE" = "true" ]; then   # "Pages: write" is distinct from Administration — don't blame visibility unread
      echo "  ⚠ Pages: unavailable on a PRIVATE repo on the Free plan → will be created on the flip to public."
    else
      echo "  ⚠ Pages: creation refused on a PUBLIC repo → the admin PAT is missing \"Pages: write\""
      echo "    (a permission DISTINCT from Administration). Add it and rerun."
    fi
  fi

  # Homepage feeds the "documentation" item of the community profile — derived from the Pages
  # site just created, closing the loop on its own.
  if [ -z "$HOMEPAGE" ]; then
    PAGES_URL=$(gh api "repos/$SLUG/pages" --jq '.html_url' 2>/dev/null || true)
    case "$PAGES_URL" in   # both outcomes speak: a silent default here would cost a community-profile point unreported
      https://*) mutate gh repo edit "$SLUG" --homepage "$PAGES_URL" >/dev/null 2>&1 \
                   && echo "  ✓ homepage = $PAGES_URL  (→ \"documentation\" item of the community profile)" \
                   || echo "  ⚠ homepage could NOT be set to $PAGES_URL — set it by hand: Settings → General → Website." ;;
      *)         echo "  ⚠ Pages URL unreadable (site may still be propagating) — homepage left UNSET."
                 echo "    Re-run this script later, or set it by hand: Settings → General → Website." ;;
    esac
  fi
fi

# 6. Ruleset 'main' — idempotent (create or update). Rules added by hand are merged in, never
#    wiped by a bare PUT (docs/code/configure-repo.md).
RULESET_NAME="main"

# CodeQL becomes a required check only once its 1st analysis exists (else every PR blocks forever
# — see "code_scanning analyses" further below, and the same 0-vs-forbidden trap it guards
# against). `build-check` required as soon as docker-publish.yml exists — unrequired, Trivy is
# decorative (repo-controls.md:290,518).
CHECKS_JSON='[ { "context": "checks" } ]'
HAS_DOCKER_WF=0   # probed once here; the ghcr block near the end asks the same question again
if gh api "repos/$SLUG/contents/.github/workflows/docker-publish.yml" >/dev/null 2>&1; then
  HAS_DOCKER_WF=1
  CHECKS_JSON='[ { "context": "checks" }, { "context": "build-check" } ]'
  echo "  ↳ ARTEFACT capability detected (docker-publish.yml) → 'build-check' (Dockerfile + Trivy scan) becomes a REQUIRED check."
fi

# The rulesets API accepts any string as a required context (repo-controls.md:705) — so each
# context is verified against the SERVER's default-branch workflows, not the working tree. Not
# caught: a job with `name:`/a matrix reports under a different check-run name; no `pull_request`
# trigger means it never reports on a PR at all.
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

# CodeQL native default setup, not a committed codeql.yml (repo-controls.md:482-504). Same
# stdout-JSON trap as gh_val() above: require `.state` to actually be present before trusting it.
DS_RAW=$(gh api "repos/$SLUG/code-scanning/default-setup" 2>/dev/null || true)
if printf '%s' "$DS_RAW" | jq -e 'has("state")' >/dev/null 2>&1; then
  DS_STATE=$(printf '%s' "$DS_RAW" | jq -r '.state')
else
  DS_STATE=unreadable
fi
if [ "$DS_STATE" = "configured" ]; then
  echo "  ✓ CodeQL default setup already active — languages detected and KEPT UP TO DATE by GitHub."
elif [ "$DS_STATE" = "unreadable" ] && [ "$IS_PRIVATE" = "false" ]; then
  # Unreadable on a PUBLIC repo must be the PAT, not a guess — else the PATCH below would also
  # fail and wrongly blame "not configured".
  echo "  ⚠ CodeQL default setup state UNREADABLE on a PUBLIC repo → the PAT is missing 'Administration'."
  echo "    CodeQL will be NEITHER enabled NOR checked. Fix the PAT, then REPLAY."
else
  if gh api "repos/$SLUG/contents/.github/workflows/codeql.yml" >/dev/null 2>&1; then   # switch → disabled_manually (repo-controls.md:503)
    echo "  ⚠ this repo carries a committed 'codeql.yml' → the switch flips it to 'disabled_manually'."
    echo "    This is INTENTIONAL: the default setup covers MORE languages, and GitHub keeps them up to date."
    echo "    → The file becomes DEAD: REMOVE it via a PR."
  fi
  # 🔴 The only write bypassing `mutate()` (its dry-run guard is kept by hand here instead) — and
  # dry-run must not lie about what would happen: docs/code/configure-repo.md.
  if [ "$DRY" -eq 1 ]; then
    mutate gh api -X PATCH "repos/$SLUG/code-scanning/default-setup" -f state=configured
    if [ "$IS_PRIVATE" = "true" ]; then
      echo "  ↳ CodeQL: the PATCH WILL FAIL — unavailable on a PRIVATE repo (Advanced Security required)."
      echo "    EXPECTED. CodeQL will activate on the NEXT RUN of this script AFTER the flip to public (§4)."
    else
      echo "  ✓ CodeQL default setup ENABLED (languages auto-detected)."
    fi
  else
    DS_RUN=$(gh_val '.run_id' '' -X PATCH "repos/$SLUG/code-scanning/default-setup" -f state=configured)
    case "$DS_RUN" in ''|*[!0-9]*) DS_RUN="" ;; esac   # run_id is an integer; anything else means activation FAILED (docs/code/configure-repo.md)
    if [ -n "$DS_RUN" ]; then
      echo "  ✓ CodeQL default setup ENABLED — 1st analysis launched (run $DS_RUN)."
      # Waiting is not a nicety: without it, `main` stays unprotected until someone reruns the
      # script. Status tested against a list of valid values, not `= "completed"` alone — a 403
      # (errors on stdout) would otherwise spin the full 6 minutes blind (docs/code/configure-repo.md).
      printf '    … waiting for the 1st analysis — without it, the rule would not be set '
      DS_DONE=0; DS_BLIND=0
      for _ in $(seq 1 36); do
        RS=$(gh_val '.status' '' "repos/$SLUG/actions/runs/$DS_RUN")
        case "$RS" in
          completed) DS_DONE=1; break ;;
          queued|in_progress|requested|waiting|pending) DS_BLIND=0; printf '.'; sleep 10 ;;
          *) DS_BLIND=$((DS_BLIND + 1))   # a transient 404 right after creation is normal — 3 in a row before blaming the PAT
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

# Three states, never collapsed to two: JSON list (ran) / 404 "no analysis found" (responds,
# nothing yet) / 403-other (not allowed to look) — docs/code/configure-repo.md.
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
else   # shouldn't happen after enabling + waiting above: this is the analysis having FAILED, not "not yet"
  echo "  ⚠ NO CodeQL analysis despite activation → the 'code_scanning' rule is NOT set."
  echo "    'main' is therefore NOT guarded by CodeQL. Check the 'CodeQL Setup' run in Actions,"
  echo "    then REPLAY this script once the analysis is green."
fi

RULESETS=$(gh api "repos/$SLUG/rulesets" 2>/dev/null || true)   # same stdout-JSON trap as gh_val() above
if ! printf '%s' "$RULESETS" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "  ⚠ rulesets UNAVAILABLE on this repo — expected on a PRIVATE repo on the Free plan (docs/repo-controls.md)."
  echo "    'main' is therefore NOT protected: no PR required, no required checks, force-push possible."
  echo "    TAGS aren't protected either → the prod version pin guarantees nothing."
  echo "    → REPLAY this script on the flip to public (full procedure: docs/repo-controls.md)."
  RULESETS=""
fi

# upsert_ruleset <name> <json> — create if absent, else merge (docs/code/configure-repo.md):
# rule types outside the supplied JSON are preserved, bypass_actors never removed silently.
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

# Squash-only and a staging branch are incompatible (squashing `develop` into `main` diverges the
# branches every cycle): if `develop` exists, `main` also accepts merge commits; `develop` stays
# squash-only.

# `delete-branch-on-merge` deletes `develop` on its own promotion-PR merge, unprotected in
# private — so staging is inferred from what the repo PUBLISHES too, not the branch alone
# (docs/code/configure-repo.md).
if [ "$WANTS_STAGING" -eq 1 ] && [ "$HAS_DEVELOP" -eq 0 ]; then
  echo "  ⚠ INCONSISTENCY — the repo PUBLISHES a THREE-stage flow, but the 'develop' branch DOES NOT EXIST."
  echo "    Near-certain cause: 'delete-branch-on-merge' DELETED it on the merge of the develop → main PR."
  echo "    In PRIVATE, no ruleset protects it: putting into production DESTROYS staging."
  echo "    Without it: no 'develop' ruleset, and 'main' falls back to SQUASH-ONLY — so the"
  echo "    next promotion becomes IMPOSSIBLE (squashing develop into main makes them diverge, docs/repo-controls.md)."
  echo "    → RECREATE IT, THEN REPLAY THIS SCRIPT:"
  echo "        git switch -c develop main && git push -u origin develop"
  echo "      The 'develop' ruleset ('deletion' rule) will then prevent it from being deleted again."
fi

# Same setting, taken upstream (warning after the fact isn't enough — `delete-branch-on-merge` is
# actually REMOVED further below when private+3-stage, restored once the ruleset takes over).

# Dependabot security updates removed here only for repos configured before §3a stopped setting
# them, and only once Renovate is proven ALIVE — freshness, not mere existence, of its Dependency
# Dashboard (docs/code/configure-repo.md).
if [ "$HAS_DEVELOP" -eq 1 ] || [ "$WANTS_STAGING" -eq 1 ]; then
  DASH_RC=0
  DASH_AT=$(gh api "repos/$SLUG/issues?state=open&per_page=100" \
    --jq 'map(select(.title=="Dependency Dashboard"))|.[0].updated_at // empty' 2>/dev/null) || DASH_RC=$?
  case "$DASH_AT" in 20[0-9][0-9]-*) ;; *) DASH_AT="" ;; esac   # shape filter: an error body else outranks any ISO date (docs/code/configure-repo.md)
  FRESH=$(date -u -v-14d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ)   # -v (BSD) then -d (GNU)
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
    && echo "  ↳ 'develop' exists → 'main' ALSO accepts merge commits (staging → prod promotion, docs/repo-controls.md)."
fi

upsert_ruleset "$RULESET_NAME" "$RULESET_JSON"

# 6b. Ruleset 'develop' — ONLY if the branch exists (STAGING capability, docs/repo-controls.md).
if [ -n "$RULESETS" ] && [ "$HAS_DEVELOP" -eq 1 ]; then
  DEV_JSON=$(printf '%s' "$RULESET_JSON" | jq -c \
    '.name = "develop"
     | .conditions.ref_name.include = ["refs/heads/develop"]
     | .rules = [ .rules[] | select(.type != "code_scanning") ]
     | (.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods) = ["squash"]')
  upsert_ruleset "develop" "$DEV_JSON"
fi

# 6c. TAGS ruleset — THIS is the control that makes the version pin real.
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

# 6c. Classic branch protection — the OTHER system, invisible to `GET /rulesets` and stacking
#     with it. Detects and reports only, never deletes — docs/code/configure-repo.md.
for BR in main develop; do
  PROT=$(gh api "repos/$SLUG/branches/$BR/protection" 2>/dev/null || true)
  [ -n "$PROT" ] || continue
  CTX=$(printf '%s' "$PROT" | jq -r '[.required_status_checks.contexts[]?] | join(", ")' 2>/dev/null || true)
  echo "  ⚠ CLASSIC branch protection still active on '$BR'${CTX:+ — required checks: $CTX}."
  echo "    It STACKS with the ruleset just set. If it requires a check that's GONE"
  echo "    (jobs renamed while adopting the template's workflows), NO PR will EVER pass."
  echo "    → remove it now that the ruleset protects: https://github.com/$SLUG/settings/branches"
done

# 7. Final check — community profile: the only indicator for "Reported content", which has no
#    API at all (repo-controls.md:690). Without this check, a missing item stays invisible.
PROFILE=$(gh api "repos/$SLUG/community/profile" 2>/dev/null || true)
if printf '%s' "$PROFILE" | jq -e '.health_percentage' >/dev/null 2>&1; then
  HEALTH=$(printf '%s' "$PROFILE" | jq '.health_percentage')
  # `issue_template` is always null when templates live in a folder (API artefact, no effect on
  # the score) — excluded below, else a missing item is reported that doesn't exist.
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
    if [ -z "$MISSING" ]; then   # nothing missing → it's the UI-only item (org repos only, RUNBOOK.md:271)
      echo "    All files are present → what's left is the NON-SCRIPTABLE item:"
      echo "    Settings > Moderation options > Reported content > 'Prior contributors and collaborators'"
      echo "    https://github.com/$SLUG/settings/moderation/reported-content"
      echo "    (No API, neither REST nor GraphQL. GitHub's default does NOT apply to a repo"
      echo "     created PRIVATE then flipped public — exactly our case.)"
    fi
  fi
else   # the check meant to catch invisible gaps must not go missing invisibly itself
  echo "  ⚠ community profile UNREADABLE — the final check did NOT run."
  echo "    Nothing below attests the score: read it by hand at https://github.com/$SLUG/community"
fi

echo "✓ $SLUG: server settings applied."
echo
echo "  ⚠️  REVOKE THE ADMIN PAT NOW — it no longer has any reason to exist:"
echo "     https://github.com/settings/personal-access-tokens"
echo
if [ "$HAS_DOCKER_WF" -eq 1 ]; then
# Verify instead of reminding — a green "Publish image" job doesn't prove the image is pullable;
# three states, not a boolean, and the package name is read from `images:`, never derived from the
# slug (docs/code/configure-repo.md).
PULL_STATE=untested
if [ "$IS_PRIVATE" = "false" ] && [ "$(gh_val 'length' 0 "repos/$SLUG/releases")" -gt 0 ]; then
  TAG=$(gh api "repos/$SLUG/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//')
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
    echo "    The PROD host CANNOT pull it: the version pin is WORTHLESS."
    echo "    Near-certain cause: the ghcr package is PRIVATE."
  fi
fi
# No image yet: inform, demand nothing — the action, if needed, is needed at the 1st release.
if [ "$PULL_STATE" = "untested" ]; then
  if [ "$IS_PRIVATE" = "true" ]; then
    echo "  ↳ PRIVATE repo: the ghcr package's visibility isn't relevant yet. It will be at the flip."
  else
    echo "  ↳ no release ⇒ NO ghcr image exists yet: nothing to make public today."
    echo "    At the 1st release, REPLAYING this script will test the anonymous pull and report it (RUNBOOK §3)."
  fi
fi
# Shown only if the anonymous pull actually failed — the default visibility depends on account
# type, so it's tested, never assumed (docs/code/configure-repo.md).
if [ "$PULL_STATE" = "ko" ]; then
  echo "  MANUAL ACTION NEEDED — ghcr package visibility (no API: fine-grained PATs do NOT"
  echo "  cover ghcr, only classic PATs do)."
  echo "     -> Package settings > Danger Zone > Change visibility > Public"
  # The packages URL DIFFERS by account type: /orgs/<o>/… for an organization,
  # /users/<o>/… for a personal account.
  OWNER_TYPE=$(gh_val '.type' 'Organization' "users/${SLUG%%/*}")
  if [ "$OWNER_TYPE" = "User" ]; then PKG_NS="users"; else PKG_NS="orgs"; fi
  echo "     https://github.com/$PKG_NS/${SLUG%%/*}/packages/container/${IMG#*/}/settings"   # $IMG: set wherever PULL_STATE=ko is
  echo "     Without this action, the anonymous pull returns 403: neither the prod host nor a"
  echo "     user can pull the image."
  echo "     Org-wide: Settings > Packages > Package creation > default visibility."
fi
fi
