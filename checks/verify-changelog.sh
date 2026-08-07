#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# A user-visible change without a CHANGELOG line — the case that happened: four checks shipped,
# CHANGELOG untouched, and a missing line leaves the file perfectly plausible.
# The perimeter is DETECTED, never listed: this travels where none of these paths exist.
# The rule, the three diff sources, and what was measured and rejected: docs/code/verify-changelog.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

# ── The FORM: one `###` of each type, a capped entry, a Release link, and the pull request ──
# Rule and sources: standard §16. Why an entry is ANY bullet, why the reference is not counted, and
# why `Unreleased` is exempt from the last refusal: docs/code/verify-changelog.md.
if [ -f CHANGELOG.md ]; then
  cap="${CHANGELOG_ENTRY_CAP:-300}"
  dup=$(awk '/^## \[/ {v=$0; sub(/^## \[/,"",v); sub(/\].*/,"",v)} v && /^### / {c[v FS $2]++}
             END {for (k in c) if (c[k] > 1) {split(k,a,FS); printf "%s/%s ", a[1], a[2]}}' CHANGELOG.md || true)
  long=$(awk -v cap="$cap" '
      /^## \[/ {ver=$0; sub(/^## \[/,"",ver); sub(/\].*/,"",ver)}
      # A reference alone on its line leaves its indentation behind: 2 spaces over the cap.
      {l=$0; gsub(/\(?\[#[0-9]+\]\(https:\/\/[^)]*\)[,)]?/,"",l); if (l ~ /^[[:space:]]*$/) l=""}
      /^- / {if (n > cap) printf "%s %s (%d) ", w, lbl, n; w=ver; lbl=substr($0,3,36); n=length(l); next}
      n && /^[[:space:]]*$/ {if (n > cap) printf "%s %s (%d) ", w, lbl, n; n=0; next}
      n && /^[[:space:]]/ {n += length(l); next}
      n {if (n > cap) printf "%s %s (%d) ", w, lbl, n; n=0}
      END {if (n > cap) printf "%s %s (%d) ", w, lbl, n}' CHANGELOG.md || true)
  no_ref=$(awk '
      /^## \[Unreleased\]/ {o=1; next} /^## \[/ {o=0}
      o {next}
      /^- / {if (cur != "" && !seen) printf "%s ", cur; cur=substr($0,3,30); seen=0}
      /\[#[0-9]+\]\(https:\/\/[^)]*\/pull\/[0-9]+\)/ {seen=1}
      END {if (cur != "" && !seen) printf "%s ", cur}' CHANGELOG.md || true)
  no_link=$(awk '/^## \[[0-9]/ && $0 !~ /\]\(http/ {n=$2; gsub(/[][]/,"",n); printf "%s ", n}' CHANGELOG.md || true)
  n_entries=$(grep -c '^- ' CHANGELOG.md || true)
  if [ -n "$no_link" ]; then
    echo "✗ CHANGELOG heading without its inline Release link: ${no_link}" >&2
    echo "  Seal it as: ## [X.Y.Z](<repo-url>/releases/tag/vX.Y.Z) - <date>" >&2
    exit 1
  fi
  if [ -n "$long" ]; then
    echo "✗ CHANGELOG entry past ${cap} characters, reference excluded:" >&2
    printf '    %s\n' "$long" >&2
    echo "  Say what changed and what it means for whoever uses the repo." >&2
    echo "  The demonstration belongs to the pull request; a LIMIT of the new behaviour stays." >&2
    exit 1
  fi
  if [ -n "$no_ref" ]; then
    echo "✗ CHANGELOG sealed entry with no pull request: ${no_ref}" >&2
    echo "  End it with: ([#N](<repo-url>/pull/N)) — several go in ONE parenthesis, comma-separated." >&2
    exit 1
  fi
  if [ -n "$dup" ]; then
    # Braces are load-bearing: a bare $name followed by a multi-byte dash is read as part of the name.
    echo "✗ CHANGELOG repeats a section: ${dup}— Keep a Changelog wants one of each per version" >&2
    echo "  Merge them: one ### per type, in the order Added / Changed / Deprecated / Removed / Fixed / Security." >&2
    exit 1
  fi
  echo "  (CHANGELOG: ${n_entries} entr(y|ies) read, every version — one section per type, none past ${cap} char. excluding its reference, every sealed one carries its pull request)"
fi

published=()
[ -d templates ]        && published+=('^templates/')
[ -f docs/RUNBOOK.md ]  && published+=('^docs/RUNBOOK\.md$')
[ -f init-project.sh ]  && published+=('^check\.sh$' '^open-pr\.sh$' '^checks/' '^init-project\.sh$' '^configure-repo\.sh$')

if [ "${#published[@]}" -eq 0 ]; then
  echo "  (nothing published from this repository is detectable here — no mechanical perimeter to check)"
  exit 0
fi

base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
git rev-parse --verify --quiet "$base" >/dev/null \
  || { echo "  (no $base to compare against — nothing to check)"; exit 0; }
here=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
if [ "$here" = "${base#origin/}" ]; then
  echo "  (on $here, the default branch itself — the unit compared is a branch, nothing to check)"
  exit 0
fi


merge_base=$(git merge-base "$base" HEAD 2>/dev/null || true)
[ -n "$merge_base" ] || { echo "  (no common ancestor with $base — nothing to compare)"; exit 0; }
# THREE sources — committed, staged, neither. Why: docs/code/verify-changelog.md.
changed=$({ git diff --name-only "$merge_base"...HEAD
            git diff --name-only --cached
            git diff --name-only; } 2>/dev/null | sort -u || true)
[ -n "$changed" ] || { echo "✓ nothing changed since $base — no CHANGELOG line owed"; exit 0; }

visible=$(printf '%s\n' "$changed" | grep -E "$(IFS='|'; echo "${published[*]}")" || true)

[ -n "$visible" ] || { echo "✓ no user-visible change in this branch (perimeter: ${#published[@]} published path(s))"; exit 0; }

if printf '%s\n' "$changed" | grep -qx 'CHANGELOG.md'; then
  echo "✓ user-visible change, and CHANGELOG.md was updated"
  exit 0
fi

{
  echo "✗ user-visible change with no CHANGELOG.md line:"
  printf '    %s\n' $visible
  echo "  Add a line under 'Unreleased' saying what it MEANS for whoever uses the repo."
  echo "  An internal refactor does not belong there — but the paths above are not that."
} >&2
exit 1
