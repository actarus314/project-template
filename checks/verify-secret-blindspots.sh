#!/usr/bin/env bash
# The places a secret can sit where gitleaks does not look. Two of them, read at the same moment
# for the same question, because gitleaks misses both for the SAME structural reason: it scans the
# CONTENT of files git knows about.
#
# 🔴 A file NAMED like a secret, tracked. gitleaks looks for secret-SHAPED strings inside files,
# never for a file CALLED .env or secrets.md. An empty .env, a secrets.md holding only headings, an
# .envrc before the token is pasted in — all pass gitleaks, get committed, and are then filled in.
# The leak happens at the NEXT commit, on a path nobody watches any more.
#
# 🔴 A token pasted into the remote URL. `.git/config` is never tracked, so gitleaks never reads it
# — not on staged files, not over the full history. A `https://<token>@github.com/...` remote
# therefore sits in plain text where NOTHING in this repository looks, and it survives every clone
# of the working copy. The credential helper is read with it: it must name a variable, never carry
# a literal.
#
# The standard states all of this. Nothing verified any of it until now.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# .env.example and .gitleaksignore are DELIBERATE: one is the documented template, the other the
# exception list. Both are meant to be tracked, and both would match a naive pattern.
# The names that betray, and they are not only .env: a private key, a registry credentials file
# and a cloud service account are all just as readable, and gitleaks reads none of them by NAME.
pattern='(^|/)(\.env|\.envrc|secrets?|credentials?|id_rsa|id_ed25519|\.npmrc|\.netrc|\.pypirc|service-account|serviceaccount)([._-][A-Za-z0-9._-]*)?$|\.(pem|key|p12|pfx|keystore|jks)$'
fail=0

# Which repositories were actually read, published with the verdict: the final message claimed
# "in either repo" whether the neighbour was there or not, so an absent workspace/ was reported as
# a workspace/ with nothing wrong in it.
scanned=""
skipped=""

scan() {
  local dir="$1" label="$2" hit
  [ -d "$dir" ] || { skipped="$skipped $label"; return 0; }
  scanned="$scanned $label"
  # templates/ holds TEMPLATES, not secrets: templates/repo/.envrc is the model copied into every
  # generated project, tracked on purpose with `git add -f` (AGENTS.md forbids un-tracking it).
  hit=$(git -C "$dir" ls-files 2>/dev/null | grep -iE "$pattern" \
        | grep -vE '\.example$|gitleaksignore|^templates/' || true)
  if [ -n "$hit" ]; then
    echo "✗ $label tracks a secret-named file: $(echo "$hit" | tr '\n' ' ')" >&2
    fail=1
  fi
}

scan . 'repo/'
scan ../workspace 'workspace/'

# A remote URL carrying credentials, and a credential helper carrying a literal. The offending
# value is NEVER printed: reporting a leak by repeating it moves it into a terminal, a log and a CI
# transcript. The remote name and the setting are enough to find it.
scan_config() {
  local dir="$1" label="$2" name url helper
  [ -d "$dir/.git" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    url=$(git -C "$dir" remote get-url "$name" 2>/dev/null || true)
    case "$url" in
      *://*@*) echo "✗ $label remote '$name' carries credentials in its URL — strip it with: git -C $dir remote set-url $name https://github.com/<owner>/<repo>.git" >&2; fail=1;;
    esac
  done < <(git -C "$dir" remote 2>/dev/null || true)

  # The documented form interpolates a variable, so the token stays in the environment. Anything
  # else in that value is a literal sitting on disk.
  while IFS= read -r helper; do
    [ -n "$helper" ] || continue
    case "$helper" in
      *'${'*|'') ;;                                  # names a variable: the documented shape
      *ghp_*|*github_pat_*|*gho_*|*ghs_*)
        echo "✗ $label a credential helper holds a literal token — replace it with a variable reference" >&2; fail=1;;
    esac
  done < <(git -C "$dir" config --get-all 'credential.https://github.com.helper' 2>/dev/null || true)
}

scan_config . 'repo/'
scan_config ../workspace 'workspace/'

scope="read:${scanned:- nothing}"
[ -n "$skipped" ] && scope="$scope — NOT read:$skipped (absent)"
[ "$fail" = 0 ] && echo "✓ no secret-named file tracked, no credential in a remote URL — $scope"
exit "$fail"
