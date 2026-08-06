#!/usr/bin/env bash
# blocking: no   (what this does with a verdict; compared to the control table AND to its real exit code)
# A stage that closed without leaving its archive behind — advisory (why: verify-stage-closure.md).
# Carries only what verify-growth.sh cannot see — the two must never re-judge one question
# (verify-stage-closure.md).
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

WS=../workspace
# Perimeter, detected rather than assumed: a generated project may have neither.
[ -d "$WS/.git" ] || { echo "  (no neighbouring workspace — nothing to read)"; exit 0; }
[ -d "$WS/archives" ] || { echo "  (no $WS/archives — this project files its stages elsewhere)"; exit 0; }

# Tags live in THIS repository; what crosses over is the release TIMESTAMP (needs `fetch-tags:
# true` in CI, or this passes by finding nothing — verify-stage-closure.md).
mapfile -t TAGS < <(git for-each-ref --sort=creatordate --format='%(refname:short)%09%(creatordate:iso-strict)' refs/tags)
if [ "${#TAGS[@]}" -lt 2 ]; then
  echo "  (fewer than two releases here — no closed interval to read)"
  exit 0
fi

prev=${TAGS[-2]}; last=${TAGS[-1]}
prev_name=${prev%%$'\t'*}; prev_at=${prev#*$'\t'}
last_name=${last%%$'\t'*}; last_at=${last#*$'\t'}

# The most recent CLOSED stage only — re-judging the whole history piles up dead findings
# (verify-stage-closure.md).
archived=$(git -C "$WS" log --format=%H --since "$prev_at" --until "$last_at" -- archives | grep -c . || true)

# What was still on the hot side when that release was cut.
rev=$(git -C "$WS" rev-list -1 --before "$last_at" HEAD 2>/dev/null || true)
hot=""
[ -n "$rev" ] && hot=$(git -C "$WS" ls-tree --name-only "$rev" | grep '^RECHERCHE-' || true)

# ⚠ marks; exit code stays 0 — advisory means the EXIT CODE, never the wording (verify-stage-closure.md).
said=0
if [ "$archived" -eq 0 ]; then
  echo "⚠ $prev_name → $last_name closed without touching $WS/archives — the stage left no synthesis"
  said=1
fi
if [ -n "$hot" ]; then
  echo "⚠ still on the hot side at $last_name: $(echo "$hot" | tr '\n' ' ')— a finished RECHERCHE-* belongs in its stage folder"
  said=1
fi

# Published either way: a bare ✓ cannot be told apart from a check that looked at nothing.
if [ "$said" -eq 0 ]; then
  echo "✓ the last closed stage left its archive — read: $prev_name → $last_name, $archived archive commit(s), no RECHERCHE-* left at the root"
else
  echo "  (advisory — the gate stays green: whether a release closed a stage is a judgement, and a"
  echo "   patch release often closes none. Settling it is the housekeeping pass, not this counter.)"
fi
echo "  (the stage opened by $last_name is left alone — it may still be running)"
exit 0
