#!/usr/bin/env bash
# Open a pull request AND make sure CI actually starts on it: GitHub intermittently fails to
# dispatch the `pull_request` run, and a PR with 0 runs reads as green though never tested
# (AGENTS.md: "0 runs is never a green"). Pushes, waits for the commit to register, opens the
# PR, then confirms a run appeared — closing/reopening once if none did: close/reopen is the
# ONLY re-trigger that reproduces a repo's REQUIRED pull_request checks.

# Usage: ./open-pr.sh <base-branch> <title> <body-file> — run via `direnv exec` so .envrc's PAT loads.

# SHARED file: init-project.sh copies it into every generated project, like check.sh.
set -euo pipefail

# The version, so the sweep that compares them all can see this one too.
if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

BASE="${1:?usage: open-pr.sh <base-branch> <title> <body-file>}"
TITLE="${2:?usage: open-pr.sh <base-branch> <title> <body-file>}"
BODY_FILE="${3:?usage: open-pr.sh <base-branch> <title> <body-file>}"
[ -f "$BODY_FILE" ] || { echo "open-pr: body file not found: $BODY_FILE" >&2; exit 2; }

# ── The form of the title, and of the body — refused HERE, before anything is pushed ────────────
# 🔴 Merging is `--squash`, so THIS TITLE is the subject that lands on the default branch. The
# `commit-msg` hook never sees it — the squash discards the commits it judged — which makes this the
# only place governing what the history ends up carrying.
# Rules and sources: METHODE.md, "The four places a change is written"; the measurement: open-pr.md.
CAP="${PR_TITLE_CAP:-72}"
n=$(printf '%s' "$TITLE" | wc -m | tr -d ' ')
title_bad=""
if [ "$n" -gt "$CAP" ]; then title_bad="runs to $n characters, past $CAP"
else
  case "$TITLE" in
    [A-Z]*) ;;
    *) title_bad="does not open on a capital";;
  esac
  case "$TITLE" in
    *.) title_bad="ends on a full stop";;
  esac
  # Only the mechanical half of the imperative, same list as the commit subject and the CHANGELOG
  # entry: it is one sentence in three places, so one wording refuses it in all three.
  first=$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z].*$//')
  case "$first" in
    the|a|an|this|that|its|it|their|there|every|no|nothing|when|after)
      title_bad="opens on '$first', which describes rather than commands";;
  esac
fi
if [ -n "$title_bad" ]; then
  echo "open-pr: this title $title_bad — nothing pushed, nothing opened." >&2
  echo "    $TITLE" >&2
  echo "  Squash-merging makes this title the commit subject on $BASE: an imperative sentence," >&2
  echo "  capitalised, at most ${CAP} characters, no full stop. It says what merging DOES." >&2
  exit 2
fi

# The sections are read from the TEMPLATE, never listed here: a project that adapts its template
# adapts what is owed with it, and one list cannot go stale against the other. No template, nothing
# to owe — and it says so rather than passing in silence.
TEMPLATE=.github/PULL_REQUEST_TEMPLATE.md
if [ -f "$TEMPLATE" ]; then
  missing=""
  while IFS= read -r heading; do
    grep -qxF "$heading" "$BODY_FILE" || missing="${missing}    ${heading}
"
  done < <(grep '^## ' "$TEMPLATE" || true)
  if [ -n "$missing" ]; then
    echo "open-pr: the body is missing a section of $TEMPLATE — nothing pushed, nothing opened." >&2
    printf '%s' "$missing" >&2
    echo "  The pull request owns the DEMONSTRATION: what was measured, what was ruled out, how to verify." >&2
    echo "  Start from the template: cp $TEMPLATE <body-file>" >&2
    exit 2
  fi
  echo "open-pr: title ${n} char., and the body carries every section of $TEMPLATE."
else
  echo "open-pr: title ${n} char. — no $TEMPLATE here, so no section is owed of the body."
fi

HEAD="$(git rev-parse --abbrev-ref HEAD)"
[ "$HEAD" != "$BASE" ] || { echo "open-pr: head and base are both '$BASE'" >&2; exit 2; }
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

# Newest pull_request run id already attached to this branch (0 if none) — monotonic, so "a NEW
# run appeared" == "newest id > baseline". Id-based, not a count: a count saturates on a long-lived
# branch (e.g. develop, >50 prior runs) and would never see a new one. Empty on a gh error.
newest_run_id() {
  local v
  v="$(gh run list --branch "$HEAD" --event pull_request -L 1 --json databaseId --jq '.[0].databaseId // 0' 2>/dev/null)" || v=""
  case "$v" in ''|*[!0-9]*) echo "" ;; *) echo "$v" ;; esac
}

# Establish the baseline, failing CLOSED: proceeding on a guess could later certify an unchecked
# PR as green — the exact harm this script exists to prevent. Abort before opening anything.
BASELINE=""
for _ in $(seq 1 5); do
  BASELINE="$(newest_run_id)"
  [ -n "$BASELINE" ] && break
  sleep 2
done
[ -n "$BASELINE" ] || { echo "open-pr: cannot read the run list to establish a baseline — aborting before opening the PR" >&2; exit 3; }

# Push, UNLESS already up to date with its upstream — a promotion opens a PR from a long-lived
# branch (e.g. develop -> main) already pushed, whose direct push the pre-push hook would refuse
# anyway; a fresh branch has none yet and is pushed with -u. Either way, let GitHub register the
# commit before opening — opening too fast is the main cause of the missed dispatch.
if git rev-parse --verify --quiet "@{upstream}" >/dev/null 2>&1 &&
   [ "$(git rev-parse HEAD)" = "$(git rev-parse '@{upstream}')" ]; then
  echo "open-pr: '$HEAD' already up to date with its upstream — skipping push."
else
  git push -u origin "$HEAD"
fi
SHA="$(git rev-parse HEAD)"
for _ in $(seq 1 15); do
  gh api "repos/$REPO/commits/$SHA" >/dev/null 2>&1 && break
  sleep 2
done

PR_URL="$(gh pr create --base "$BASE" --head "$HEAD" --title "$TITLE" --body-file "$BODY_FILE")"
PR="${PR_URL##*/}"
echo "open-pr: opened #$PR -> $PR_URL"

# Wait up to ~60 s for a NEW pull_request run (id above the baseline); a gh error yields an empty
# id, treated as "not yet" — never as success, so the guard stays fail-closed throughout.
wait_for_dispatch() {
  local v
  for _ in $(seq 1 20); do
    v="$(newest_run_id)"
    [ -n "$v" ] && [ "$v" -gt "$BASELINE" ] && return 0
    sleep 3
  done
  return 1
}

if wait_for_dispatch; then
  echo "open-pr: CI dispatched."
else
  echo "open-pr: no pull_request run after ~45 s — known GitHub dispatch miss; re-firing (close/reopen)." >&2
  gh pr close "$PR"
  gh pr reopen "$PR"
  if wait_for_dispatch; then
    echo "open-pr: CI dispatched after reopen."
  else
    echo "open-pr: STILL no run after reopen — dispatch it manually and DO NOT merge on an empty check list." >&2
    exit 1
  fi
fi
echo "$PR_URL"
