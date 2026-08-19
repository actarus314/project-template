#!/usr/bin/env bash
# blocking: yes   rule: AGENTS.md   (what this does with a verdict; compared to the control table AND to its real exit code)
# Two places a secret can sit where gitleaks only scans file CONTENT: a file NAMED like a secret,
# tracked; a token pasted into the remote URL. Why, and why nothing is printed: verify-secret-blindspots.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

# Each rule carries a TAG, and it is what reaches the journal: one control name for several
# rules left no way to know which of them ever bit. Absent CHECK_TAGS, the tag goes nowhere.
tag() { [ -n "${CHECK_TAGS:-}" ] && printf '%s\n' "$1" >>"$CHECK_TAGS"; return 0; }

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# .env.example and .gitleaksignore are deliberately tracked exceptions to this pattern below —
# and the names that betray are not only .env: a key, a registry credentials file, a service account.
pattern='(^|/)(\.env|\.envrc|secrets?|credentials?|id_rsa|id_ed25519|\.npmrc|\.netrc|\.pypirc|service-account|serviceaccount)([._-][A-Za-z0-9._-]*)?$|\.(pem|key|p12|pfx|keystore|jks)$'
fail=0

# Which repositories were actually read, published with the verdict (why: verify-secret-blindspots.md).
scanned=""
skipped=""

scan() {
  local dir="$1" label="$2" hit
  [ -d "$dir" ] || { skipped="$skipped $label"; return 0; }
  scanned="$scanned $label"
  # templates/ holds TEMPLATES, not secrets: templates/repo/.envrc is the model copied into every
  # generated project, tracked on purpose with `git add -f` (AGENTS.md forbids un-tracking it).
  hit=$(git -C "$dir" ls-files 2>/dev/null | grep -iE "$pattern" \
        | grep -vE '\.example$|gitleaksignore|^templates/|\.(md|txt|rst|html)$' || true)
  if [ -n "$hit" ]; then
    tag secret-named-file
    echo "✗ $label tracks a secret-named file: $(echo "$hit" | tr '\n' ' ')" >&2
    fail=1
  fi
}

scan . 'repo/'
scan ../workspace 'workspace/'

# A remote URL carrying credentials, and a credential helper carrying a literal — the offending
# value is NEVER printed (why: verify-secret-blindspots.md); the remote name and the setting are enough to find it.
scan_config() {
  local dir="$1" label="$2" name url helper
  [ -d "$dir/.git" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    url=$(git -C "$dir" remote get-url "$name" 2>/dev/null || true)
    case "$url" in
      # CAPITALS, deliberately not angle brackets: this file travels, and the generator scans what
      # it just wrote for unsubstituted placeholders (why: verify-secret-blindspots.md).
      *://*@*) tag credential-in-remote-url; echo "✗ $label remote '$name' carries credentials in its URL — strip it with: git -C $dir remote set-url $name https://github.com/OWNER/REPO.git" >&2; fail=1;;
    esac
  done < <(git -C "$dir" remote 2>/dev/null || true)

  # The documented form interpolates a variable, so the token stays in the environment. Anything
  # else in that value is a literal sitting on disk.
  while IFS= read -r helper; do
    [ -n "$helper" ] || continue
    case "$helper" in
      *'${'*|'') ;;                                  # names a variable: the documented shape
      *ghp_*|*github_pat_*|*gho_*|*ghs_*)
        tag literal-token-in-helper
        echo "✗ $label a credential helper holds a literal token — replace it with a variable reference" >&2; fail=1;;
    esac
  done < <(git -C "$dir" config --get-all 'credential.https://github.com.helper' 2>/dev/null || true)
}

scan_config . 'repo/'
scan_config ../workspace 'workspace/'

# A HOME path in versioned content: the shape a personal line takes when it slips into a published
# file. Measured before being enabled — zero occurrences across the whole tree, so it costs nothing
# today and speaks the day one appears. Excluded on purpose: the CHANGELOG quotes past incidents.
home_paths=$(git ls-files -z | grep -zv '^CHANGELOG\.md$' \
  | xargs -0 grep -nE "/(Users|home)/[a-z][a-z0-9_-]+/" 2>/dev/null || true)
if [ -n "$home_paths" ]; then
  tag machine-path-published
  echo "✗ a machine path sits in versioned content — it says who wrote it and from where:" >&2
  printf '%s\n' "$home_paths" | head -10 >&2
  fail=1
fi
scanned="$scanned home-paths"

scope="read:${scanned:- nothing}"
[ -n "$skipped" ] && scope="$scope — NOT read:$skipped (absent)"
[ "$fail" = 0 ] && echo "✓ no secret-named file tracked, no credential in a remote URL, no machine path — $scope"
exit "$fail"
