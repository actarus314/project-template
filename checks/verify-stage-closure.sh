#!/usr/bin/env bash
# blocking: no   (what this does with a verdict; compared to the control table AND to its real exit code)
# A stage that closed without leaving its archive behind.
#
# METHODE names three gestures at every closed stage: prune the hot side, write the stage's
# archive, and file its research there. The first is already guarded — verify-growth.sh watches a
# curated document that only ever grows, and compares against the last release. This one carries
# ONLY what that check cannot see, because two controls answering one question end up disagreeing.
#
# 🔴 The trigger was chosen on a MEASUREMENT, and the obvious one lost. "A merged pull request
# should be followed by a write to the tracking doc" looks compelling: 99% of them are, within 24h.
# Against 400 instants drawn at random over the same period, 88% are too — an 11 point edge, and a
# guard that would bite on 1 pull request out of 107. At 72h the edge is zero. During an active
# session the tracking doc is written several times a day AND several pull requests land, so the
# correlation comes from density, not from cause. A RELEASE is a closure; a fix's pull request is
# not. (The method — a control group of random instants — and the figures: the stage's RECHERCHE.)
#
# What the release decides is the REFERENCE POINT, never the rhythm: this runs at every commit, like
# its siblings, and speaks the moment an interval is left empty — not at the next release.
#
# ⚠ ADVISORY, and that follows this repository's own rule rather than caution: a verdict that
#   depends on context is a warning, never a block. A patch release does not necessarily close a
#   stage, and nothing mechanical distinguishes one that does from one that does not. Blocking on
#   that would refuse commits over a judgement call — which is how a guard earns its own bypass.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

WS=../workspace
# Perimeter, detected rather than assumed: a generated project may have no neighbouring workspace,
# and one that has none is not in breach of anything. It says so instead of passing silently.
[ -d "$WS/.git" ] || { echo "  (no neighbouring workspace — nothing to read)"; exit 0; }
[ -d "$WS/archives" ] || { echo "  (no $WS/archives — this project files its stages elsewhere)"; exit 0; }

# Tags come from THIS repository; the workspace carries none. What crosses over is the release
# TIMESTAMP — both repositories advance on the same undertaking. Same parade as verify-growth.sh.
# 🔴 Needs `fetch-tags: true` in a CI checkout, or the list is empty and this passes by finding
# nothing — a guard failing by passing.
mapfile -t TAGS < <(git for-each-ref --sort=creatordate --format='%(refname:short)%09%(creatordate:iso-strict)' refs/tags)
if [ "${#TAGS[@]}" -lt 2 ]; then
  echo "  (fewer than two releases here — no closed interval to read)"
  exit 0
fi

prev=${TAGS[-2]}; last=${TAGS[-1]}
prev_name=${prev%%$'\t'*}; prev_at=${prev#*$'\t'}
last_name=${last%%$'\t'*}; last_at=${last#*$'\t'}

# The most recent CLOSED stage, and only that one. Re-judging the whole history would pile up
# findings nobody can act on — an archive not written three months ago cannot be written now, and a
# wall of stale complaints is read once and then ignored.
archived=$(git -C "$WS" log --format=%H --since "$prev_at" --until "$last_at" -- archives | grep -c . || true)

# What was still sitting on the hot side when that release was cut. A RECHERCHE-* belongs to its
# stage folder once the stage is done; left at the root it is the sign the filing never happened.
rev=$(git -C "$WS" rev-list -1 --before "$last_at" HEAD 2>/dev/null || true)
hot=""
[ -n "$rev" ] && hot=$(git -C "$WS" ls-tree --name-only "$rev" | grep '^RECHERCHE-' || true)

# ⚠ marks, and the exit code stays 0. Advisory is a claim about the EXIT CODE, not about the
# wording: check.sh turns any non-zero into a ko, which fails the gate and blocks the commit — so a
# script that prints ✗ and exits 1 is a blocking check whatever its header says.
said=0
if [ "$archived" -eq 0 ]; then
  echo "⚠ $prev_name → $last_name closed without touching $WS/archives — the stage left no synthesis"
  said=1
fi
if [ -n "$hot" ]; then
  echo "⚠ still on the hot side at $last_name: $(echo "$hot" | tr '\n' ' ')— a finished RECHERCHE-* belongs in its stage folder"
  said=1
fi

# What was READ, published whether or not anything was found: a bare ✓ cannot be told apart from a
# check that looked at nothing. This repository has paid for that distinction.
if [ "$said" -eq 0 ]; then
  echo "✓ the last closed stage left its archive — read: $prev_name → $last_name, $archived archive commit(s), no RECHERCHE-* left at the root"
else
  echo "  (advisory — the gate stays green: whether a release closed a stage is a judgement, and a"
  echo "   patch release often closes none. Settling it is the housekeeping pass, not this counter.)"
fi
echo "  (the stage opened by $last_name is left alone — it may still be running)"
exit 0
