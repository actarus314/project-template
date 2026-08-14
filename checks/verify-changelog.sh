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
  # The summary a version opens on, and which release-notes.sh copies into the Release. THREE lines
  # is the maintainer's objective, not an average: past that it stops being scannable, which is the
  # only thing it is for. Unbounded, it would grow back into the copy that was just removed.
  scap="${CHANGELOG_SUMMARY_CAP:-3}"
  long_sum=$(awk -v cap="$scap" '
      /^## \[/ {if (in_v && n > cap) printf "%s (%d) ", ver, n
                ver=$0; sub(/^## \[/,"",ver); sub(/\].*/,"",ver); in_v=1; n=0; next}
      in_v && /^### / {if (n > cap) printf "%s (%d) ", ver, n; in_v=0; n=0; next}
      in_v && /^> / {n++}
      END {if (in_v && n > cap) printf "%s (%d) ", ver, n}' CHANGELOG.md || true)
  no_ref=$(awk '
      /^## \[Unreleased\]/ {o=1; next} /^## \[/ {o=0}
      o {next}
      /^- / {if (cur != "" && !seen) printf "%s ", cur; cur=substr($0,3,30); seen=0}
      /\[#[0-9]+\]\(https:\/\/[^)]*\/pull\/[0-9]+\)/ {seen=1}
      END {if (cur != "" && !seen) printf "%s ", cur}' CHANGELOG.md || true)
  no_link=$(awk '/^## \[[0-9]/ && $0 !~ /\]\(http/ {n=$2; gsub(/[][]/,"",n); printf "%s ", n}' CHANGELOG.md || true)
  n_entries=$(grep -c '^- ' CHANGELOG.md || true)
  # Only the mechanical half of each rule is read; the meaning stays a judgement.
  not_imper=$(awk '
      /^- / {e=$0; sub(/^- /,"",e); sub(/^\*\*(~~)?/,"",e)
             w=tolower(e); sub(/[^a-z`].*$/,"",w)
             if (w ~ /^(the|a|an|this|that|its|it|their|there|every|no|nothing|when|after)$/)
               printf "%s ", substr(e,1,26)}' CHANGELOG.md || true)
  opens_code=$(awk '/^- \*\*`/ {e=$0; sub(/^- \*\*/,"",e); printf "%s ", substr(e,1,26)}' CHANGELOG.md || true)
  # A reference points where it says, and a sealed entry cannot cite an unmerged pull request.
  ref_mismatch=$(awk '{line=$0
      while (match(line, /\[#[0-9]+\]\(https:\/\/[^)]*\/pull\/[0-9]+\)/)) {
        s=substr(line,RSTART,RLENGTH); line=substr(line,RSTART+RLENGTH)
        match(s, /#[0-9]+/);      lab=substr(s,RSTART+1,RLENGTH-1)
        match(s, /\/pull\/[0-9]+/); url=substr(s,RSTART+6,RLENGTH-6)
        if (lab != url) printf "#%s→/pull/%s ", lab, url}}' CHANGELOG.md || true)
  newest_pr=$(git log --oneline main 2>/dev/null | grep -oE '\(#[0-9]+\)' | tr -d '()#' | sort -n | tail -1 || true)
  ahead=$(awk -v mx="${newest_pr:-0}" '
      /^## \[Unreleased\]/ {o=1; next} /^## \[/ {o=0} o {next}
      mx > 0 {while (match($0, /\[#[0-9]+\]/)) {n=substr($0,RSTART+2,RLENGTH-3)
              if (n+0 > mx+0) printf "#%s ", n; $0=substr($0,RSTART+RLENGTH)}}' CHANGELOG.md || true)
  if [ -n "$no_link" ]; then
    echo "✗ CHANGELOG heading without its inline Release link: ${no_link}" >&2
    echo "  Seal it as: ## [X.Y.Z](<repo-url>/releases/tag/vX.Y.Z) - <date>" >&2
    exit 1
  fi
  if [ -n "$long_sum" ]; then
    echo "✗ CHANGELOG version summary past ${scap} lines:" >&2
    printf '    %s\n' "$long_sum" >&2
    echo "  It opens a version with what it is worth scanning for, and the Release copies it verbatim." >&2
    echo "  What does not fit is already below, as an entry: the summary points, it does not list." >&2
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
  if [ -n "$ref_mismatch" ]; then
    echo "✗ CHANGELOG reference points elsewhere than it says: ${ref_mismatch}" >&2
    echo "  The label and the URL must carry the same number." >&2
    exit 1
  fi
  if [ -n "$ahead" ]; then
    echo "✗ CHANGELOG sealed entry cites a pull request newer than any merged (#${newest_pr}): ${ahead}" >&2
    echo "  A sealed entry names the pull request that DELIVERED the change, and it is already merged." >&2
    exit 1
  fi
  if [ -n "$not_imper" ]; then
    echo "✗ CHANGELOG entry does not open on a present-tense verb: ${not_imper}" >&2
    echo "  Write 'Add…', 'Fix…', 'Stop…' — it says what upgrading does (standard §16)." >&2
    exit 1
  fi
  if [ -n "$opens_code" ]; then
    echo "✗ CHANGELOG entry opens on the file that changed, not on the effect: ${opens_code}" >&2
    echo "  A reader may never have opened this repository. Name what changes for them first." >&2
    exit 1
  fi
  if [ -n "$dup" ]; then
    # Braces are load-bearing: a bare $name followed by a multi-byte dash is read as part of the name.
    echo "✗ CHANGELOG repeats a section: ${dup}— Keep a Changelog wants one of each per version" >&2
    echo "  Merge them: one ### per type, in the order Added / Changed / Deprecated / Removed / Fixed / Security." >&2
    exit 1
  fi
  echo "  (CHANGELOG: ${n_entries} entr(y|ies) read, every version — one section per type, no summary past ${scap} lines, no entry past ${cap} char. excluding its reference, each opening on a verb and on the effect, every sealed one citing a merged pull request whose label matches its URL. Which section an entry belongs to, and whether it is TRUE, are judgements no check reads.)"
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
