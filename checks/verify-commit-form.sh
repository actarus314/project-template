#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# The commit subject is the sentence that lands in the history and is read years later. It has TWO
# entry points — the `commit-msg` hook passes the message being written, the lot passes nothing and
# the branch's commits are read — so that one instrument answers both and they cannot disagree.
# What it deliberately does not read, and why bots are exempt: docs/code/verify-commit-form.md
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# 72 is where GitHub truncates a subject; Chris Beams targets 50. The wall is the truncation, so it
# comes from the renderer and not from the average of what is being corrected (standard §16).
CAP="${COMMIT_SUBJECT_CAP:-72}"

# The refusals, in one place, applied identically to a message being written and to a commit already
# made. Prints the reason and nothing when the subject holds.
judge() {   # <subject>
  local s="$1" n w
  # git writes these itself; refusing them would block a merge or a revert on their generated wording.
  case "$s" in Merge\ *|Revert\ *|fixup!*|squash!*|amend!*) return 0;; esac
  [ -n "$s" ] || { echo "no subject at all"; return 0; }
  # `wc -m` counts characters under a UTF-8 locale and bytes under C: an em dash then reads as three,
  # which refuses early and never passes wrongly.
  n=$(printf '%s' "$s" | wc -m | tr -d ' ')
  if [ "$n" -gt "$CAP" ]; then echo "$n characters, past $CAP"; return 0; fi
  case "$s" in
    [A-Z]*) ;;
    *) echo "does not open on a capital"; return 0;;
  esac
  case "$s" in
    *.) echo "ends on a full stop"; return 0;;
  esac
  # Only the mechanical half of the imperative is read: a subject opening on an article or a pronoun
  # is describing the change rather than commanding it. The same list guards the CHANGELOG, and it is
  # written twice on purpose — the generator copies `checks/verify-*.sh` alone, so a shared library
  # would not travel (docs/code/verify-commit-form.md).
  w=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z].*$//')
  case "$w" in
    the|a|an|this|that|its|it|their|there|every|no|nothing|when|after)
      echo "opens on '$w', which describes rather than commands"; return 0;;
  esac
}

explain() {
  echo "  A subject is an imperative sentence, capitalised, at most ${CAP} characters, no full stop." >&2
  echo "  It says what applying the commit DOES: 'Add…', 'Fix…', 'Stop…' (standard §16)." >&2
  echo "  The commit owns the INTENTION; the diff shows the how, the pull request the demonstration." >&2
}

# ── Entry point 1: a message being written, handed over by the `commit-msg` hook ────────────────
if [ "${1:-}" = "--message" ]; then
  f="${2:?usage: verify-commit-form.sh --message <file>}"
  [ -f "$f" ] || { echo "✗ no message file at $f" >&2; exit 2; }
  # `--verbose` appends the diff below a scissors line, uncommented: it has to go before the comments,
  # or the diff's own lines survive and become the body.
  msg=$(sed -e '/^# *-\{5,\} >8 -\{5,\}/,$d' -e '/^#/d' "$f")
  subject=$(printf '%s\n' "$msg" | sed -n '1p')
  second=$(printf '%s\n' "$msg" | sed -n '2p')
  case "$subject" in
    Merge\ *|Revert\ *|fixup!*|squash!*|amend!*)
      echo "  (git wrote this subject itself — exempt, nothing of a person's writing to read)"
      exit 0;;
  esac
  if reason=$(judge "$subject") && [ -n "$reason" ]; then
    echo "✗ commit subject ${reason}:" >&2
    echo "    ${subject}" >&2
    explain
    exit 1
  fi
  # A body glued to the subject makes git read the whole paragraph as the subject — which is why the
  # branch-side pass below cannot see this rule at all, and why the hook is where it is checked.
  if [ -n "$second" ]; then
    echo "✗ commit body starts on line 2, with no blank line after the subject" >&2
    echo "    ${second}" >&2
    echo "  Leave line 2 empty: git reads the first paragraph as the subject otherwise." >&2
    exit 1
  fi
  echo "  (commit subject read, ${#subject} char.: capitalised, at most ${CAP}, no full stop, not opening on an article — and line 2 left blank)"
  exit 0
fi

# ── Entry point 2: the commits this branch adds, which is all the CI can see ────────────────────
base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
git rev-parse --verify --quiet "$base" >/dev/null \
  || { echo "  (no $base to compare against — no commit of this branch to read)"; exit 0; }
here=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
if [ "$here" = "${base#origin/}" ]; then
  # The published history is not rewritten, so judging it would only ever report what cannot be fixed.
  echo "  (on $here, the default branch itself — the unit judged is a branch, nothing to read)"
  exit 0
fi
merge_base=$(git merge-base "$base" HEAD 2>/dev/null || true)
[ -n "$merge_base" ] || { echo "  (no common ancestor with $base — nothing to compare)"; exit 0; }

bad=""
n_read=0
n_bot=0
while IFS=$'\x1f' read -r sha author subject; do
  [ -n "$sha" ] || continue
  # A bot writes its own subjects and cannot be told to rewrite them: refusing here would turn every
  # Renovate pull request red, and a guard that blocks the update bot is a guard that gets removed.
  case "$author" in *'[bot]') n_bot=$((n_bot + 1)); continue;; esac
  n_read=$((n_read + 1))
  if reason=$(judge "$subject") && [ -n "$reason" ]; then
    bad="${bad}    ${sha:0:8}  ${subject}
      → ${reason}
"
  fi
done < <(git log --no-merges --format="%H%x1f%an%x1f%s" "$merge_base..HEAD" 2>/dev/null || true)

if [ -n "$bad" ]; then
  echo "✗ commit subject out of form, on this branch:" >&2
  printf '%s' "$bad" >&2
  explain
  echo "  Reword them: git rebase -i ${merge_base:0:8} — they are not published yet." >&2
  exit 1
fi

suffix=""
[ "$n_bot" -gt 0 ] && suffix=", ${n_bot} bot commit(s) exempt"
if [ "$n_read" -eq 0 ]; then
  echo "  (no commit of this branch to read${suffix} — the form is judged on what a person wrote)"
else
  echo "  (${n_read} commit subject(s) read since ${merge_base:0:8}${suffix}: each capitalised, at most ${CAP} char., no full stop, none opening on an article. Whether the sentence commands is a judgement no check reads.)"
fi
