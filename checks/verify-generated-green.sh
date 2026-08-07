#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A generated project is born GREEN, or its very first pull request is blocked: its own ci.yml
# plays `check.sh --house`. Why the checks must run THERE: verify-generated-green.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# Subject boundary AND recursion stop — said out loud, never a silent exit (why: the note).
if [ ! -f init-project.sh ]; then
  echo "  (no init-project.sh here — nothing generates projects from this repository, nothing to check)"
  exit 0
fi

# Read from init-project.sh itself: a hand-written list goes stale in silence (as verify-travel).
types=$(sed -n 's/^case "\$TYPE" in \([a-z|]*\)).*/\1/p' init-project.sh | head -1 | tr '|' ' ')
caps=$(grep -oE '^[[:space:]]+--[a-z]+\)[[:space:]]+[A-Z]+=1;' init-project.sh \
       | grep -oE '\-\-[a-z]+' | sort -u | tr '\n' ' ' || true)   # `|| true`: see verify-travel.sh — 0 matches must reach the message, not kill the script
[ -n "$types" ] || { echo "✗ cannot read the toolchains from init-project.sh — this check would pass by looking at nothing" >&2; exit 1; }
[ -n "$caps" ]  || { echo "✗ cannot read the capabilities from init-project.sh — same reason" >&2; exit 1; }

# ONE variant, the richest — and that is a deliberate limit, not an oversight (why: the note).
first=${types%% *}
label="$first+all"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# stdout muted (the next-steps guide); stderr STAYS: this generator warns without failing.
# shellcheck disable=SC2086  # $caps is a flag list, word splitting is what makes it one
if ! ./init-project.sh greenprobe actarus314/greenprobe "$tmp" --type "$first" $caps >/dev/null; then
  echo "✗ generation failed for variant '$label' — cannot check the door of a generated project" >&2
  exit 1
fi

gen="$tmp/greenprobe/repo"
[ -x "$gen/check.sh" ] || { echo "✗ a generated project has no executable check.sh — its ci.yml calls one" >&2; exit 1; }

out="$tmp/house.log"
shipped=$(find "$gen/checks" -name 'verify-*.sh' | wc -l | tr -d ' ')
if (cd "$gen" && ./check.sh --house) >"$out" 2>&1; then
  echo "✓ a generated project is born green — read: variant '$label', $shipped check(s) shipped, its --house door run on the spot"
  exit 0
fi

echo "✗ a generated project is born RED — its first pull request is blocked before anyone touches it:" >&2
# A red with NO ✗ line is a real case — a mutely-dying check (why: the note).
total=$(grep -cE '✗' "$out" || true)
: "${total:=0}"
if [ "$total" -eq 0 ]; then
  echo "  (no ✗ line — a check exited non-zero WITHOUT saying anything; last lines follow)" >&2
  tail -15 "$out" >&2
else
  grep -E '✗' "$out" | head -25 >&2
  [ "$total" -gt 25 ] && echo "  … and $((total - 25)) more" >&2
fi
echo "  variant '$label'. Replay it: ./init-project.sh probe owner/probe /tmp/x --type $first $caps && (cd /tmp/x/probe/repo && ./check.sh --house)" >&2
exit 1
