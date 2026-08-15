#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# The neighbouring workspace/ — the one place no other control can see (why: verify-workspace.md).
# Verifiable only: git repo, no remote, no secret-named file tracked, one tracking system.
# NOT verifiable, and never to be promised: whether the tracking document's CONTENT is true.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

ws=../workspace
# An absent neighbour and a clean one produce the same empty output — said out loud on purpose,
# since this is the one check whose whole reason to exist is looking over there (verify-workspace.md).
[ -d "$ws" ] || { echo "  (no $ws beside this repo — nothing to check)"; exit 0; }

fail=0
not_read=""
say() { echo "✗ workspace/: $1" >&2; fail=1; }
# A verdict on the NEIGHBOUR's local config, which no commit here can repair and which this
# repository never receives through a diff — blocking on it stops the work in repo/ for a fault
# sitting next door, and the exact command to repair it is in the message.
warn() { echo "⚠ workspace/: $1" >&2; }

if ! git -C "$ws" rev-parse --git-dir >/dev/null 2>&1; then
  say "not a git repository — a plain folder has no history and no safety net"
else
  remotes=$(git -C "$ws" remote 2>/dev/null || true)
  if [ -n "$remotes" ]; then
    say "HAS A REMOTE ($(echo "$remotes" | tr '\n' ' ')) — it carries private names; this must never be pushed"
  fi

  # A tracked NAME betrays, not the content — gitleaks already scans content (verify-workspace.md).
  tracked=$(git -C "$ws" ls-files 2>/dev/null | grep -iE '(^|/)(secrets?|\.env)(\.[a-z]+)?$' || true)
  [ -n "$tracked" ] && say "tracks a secret-named file: $(echo "$tracked" | tr '\n' ' ')"

  # The workspace's own gate. The armed path is RESOLVED before being judged, because each way of
  # getting it wrong is silent on its own: an unset core.hooksPath runs the default hooks (there are
  # none), a path pointing nowhere makes git run nothing at all, and a path pointing at ANOTHER hooks
  # directory runs someone else's hook while this gate stays absent. A LOCAL config travels through
  # no diff, so a regenerated project arrives here unarmed — hence the exact command in the message.
  gate_dir="$PWD/.githooks-workspace"   # this repository's own, whatever the directory is named
  if [ ! -f "$gate_dir/pre-commit" ]; then
    not_read="$not_read .githooks-workspace/pre-commit(absent here — nothing to arm)"
  elif [ ! -x "$gate_dir/pre-commit" ]; then
    say "$gate_dir/pre-commit is not executable — git ignores a hook without that bit, and says nothing"
  else
    hp=$(git -C "$ws" config --local --get core.hooksPath 2>/dev/null || true)
    # git honours an ABSOLUTE hooksPath; a relative one is read from the work tree's top level.
    case "$hp" in
      "") armed="";;
      /*) armed="$hp";;
      *)  armed="$ws/$hp";;
    esac
    resolved=""
    [ -n "$armed" ] && resolved=$(cd "$armed" 2>/dev/null && pwd -P || true)
    if [ -z "$hp" ]; then
      warn "has NO gate — the checks that read it only run when this repository is committed too, and a session touching the workspace alone passes none. Arm it:
    git -C $ws config --local core.hooksPath ../$(basename "$PWD")/.githooks-workspace"
      read_gate=", gate NOT wired"
    elif [ -z "$resolved" ]; then
      warn "core.hooksPath is '$hp', which resolves to no directory — git then runs NOTHING, and says nothing"
      read_gate=", gate NOT wired"
    elif [ "$resolved" != "$(cd "$gate_dir" && pwd -P)" ]; then
      warn "core.hooksPath is '$hp' → $resolved, which is not this gate — those hooks run, this one never does"
      read_gate=", gate NOT wired"
    else
      read_gate=", gate wired"
    fi
  fi

  # ONE tracking system (METHODE). Archives excluded: a closed stage keeps its own account.
  n=$(git -C "$ws" ls-files 2>/dev/null | grep -icE '(^|/)(SUIVI|TRACKING|PROGRESS)\.md$' || true)
  systems=$n
  # A SYSTEM, not a file — .planning/ beside a SUIVI.md is two systems too (verify-workspace.md).
  OTHERS=".planning .gsd .taskmaster"
  found_others=""
  for d in $OTHERS; do
    if git -C "$ws" ls-files "$d" 2>/dev/null | grep -q .; then
      systems=$((systems + 1)); found_others="$found_others $d/"
    fi
  done
  [ "$systems" -gt 1 ] &&
    say "$systems tracking systems compete (${n} doc(s)${found_others:+, plus${found_others}}) — METHODE allows one, and the stale one gets read first"

  # Named below, never counted as a fault by itself — this list of rival tools cannot be
  # complete, so the verdict publishes what it looked for (verify-workspace.md).
  INNOCENT=".github .gitlab .vscode .idea .devcontainer .husky .claude .config .cache .venv"
  unlisted=""
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case " $OTHERS $INNOCENT " in *" $d "*) continue;; esac
    unlisted="$unlisted $d/"
  done < <(git -C "$ws" ls-files 2>/dev/null | grep '/' | cut -d/ -f1 | grep -E '^\.[a-zA-Z]' | sort -u || true)

  # A closed item belongs in the state section or an archive, never in the open-work backlog —
  # catches only that FORM, a habit rather than a guarantee (rule and incident: verify-workspace.md).
  track=$(ls "$ws"/SUIVI.md "$ws"/docs/SUIVI.md 2>/dev/null | head -1 || true)
  if [ -z "$track" ]; then
    :   # no tracking doc of the shape this rule describes: nothing to say, and it is not a fault
  else
    # Marks only at the START of a cell — elsewhere it's prose quoting the rule, not a mark
    # (incident: verify-workspace.md).
    stale=$(awk '
      /^## / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }
      inside && /^\|/ && /\|[[:space:]]*(✅|✔|☑|~~|LIVRÉ|LIVRE|DONE|FAIT|TERMINÉ|TERMINE|CLOS)/ { print NR ": " substr($0, 1, 72) }   # fr-pattern: the doc it reads is French
    ' "$track" || true)
    if [ -n "$stale" ]; then
      say "closed items are sitting in the open-work section of $(basename "$track") — they belong in the state section or an archive:
$stale"
    fi
    read_backlog=" backlog hygiene"

    # A chantier number is never reused — an archive reference has to keep resolving, and one has
    # already stopped: two numbers freed in July were handed out again in August, before the rule
    # existed. Read from the FIRST cell of a table row, never from prose: a number in a sentence is
    # a reference, not a claim to the number. Why only same-section duplicates: verify-workspace.md.
    nums=$(awk '
      /^## / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }   # fr-pattern: the doc it reads is French
      inside && /^\|[[:space:]]*(▶[[:space:]]*)?\*\*[0-9]/ {
        if (match($0, /\*\*[0-9]+(\.[0-9]+)?\*\*/)) print substr($0, RSTART + 2, RLENGTH - 4)
      }' "$track" || true)
    dup=$(printf '%s\n' "$nums" | sed '/^$/d' | sort | uniq -d)
    if [ -n "$dup" ]; then
      say "two open chantiers share a number in $(basename "$track") — a number is never reused, or an archive pointer stops resolving:
$(printf '%s\n' "$dup" | sed 's/^/  /')"
    fi
    read_numbers=", $(printf '%s\n' "$nums" | sed '/^$/d' | sort -u | wc -l | tr -d ' ') open chantier number(s), duplicates only"

    # The FORM of a task, five rules, each binary. A task
    # opens on a mark and a number, then an infinitive verb; it holds no link and no more than 72
    # characters — the commit-subject limit, since a subject and a task are the same object. What is
    # NOT here is "no retelling", which is a judgement. Why 72 and not a measured cap: verify-workspace.md.
    bad=$(awk -F'|' '
      /^## / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }   # fr-pattern: the doc it reads is French
      inside && /^\|[[:space:]]*(▶[[:space:]]*)?\*\*[0-9]/ {
        row = $0; n = split($4, seg, "<br>")
        for (i = 1; i <= n; i++) {
          s = seg[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
          if (s !~ /^(✅|⬜)/) continue                      # not a task line: the cell may open on a label
          t = s; sub(/^(✅|⬜)[[:space:]]*/, "", t)
          if (t !~ /^\*\*[0-9]+\.[0-9]+\*\*/) { print "  unnumbered: " substr(s,1,60); continue }
          sub(/^\*\*[0-9]+\.[0-9]+\*\*[[:space:]]*/, "", t)
          sub(/^\*\*[^*]+\*\*[[:space:]]*:[[:space:]]*/, "", t)   # an owner prefix is not the verb
          if (t ~ /\]\(/) print "  holds a link: " substr(t,1,50)
          bare = t; gsub(/\*|`|\*\*/, "", bare)
          if (length(bare) > 72) print "  " length(bare) " char.: " substr(bare,1,50)
          w = t; sub(/[[:space:]].*$/, "", w); gsub(/\*|`/, "", w)
          if (w !~ /(er|ir|re|oir)$/) print "  not an infinitive: " w
        }
      }' "$track" || true)
    if [ -n "$bad" ]; then
      say "a task is out of form in $(basename "$track") — numbered, opening on an infinitive, no link, at most 72 characters:
$bad"
    fi

    # A chantier folder carries its DETAILS.md — the file that reasons its tasks. Named exactly,
    # never "a file": a stage folder already holds several, and presence of any proves nothing.
    # Only a folder whose prefix names an OPEN chantier: a permanent side channel, a dead chantier
    # and a folder that predates the numbering all carry none, and demanding one there invents work.
    open_re=$(printf '%s\n' "$nums" | sed '/^$/d' | awk '{printf "%03d\n", $0}' | sort -u | paste -sd'|' -)
    missing=$(cd "$ws" && for d in WIP/*/; do
      p=${d#WIP/}; p=${p%%--*}
      printf '%s' "$p" | tr '-' '\n' | grep -qE "^(${open_re})$" || continue
      [ -f "$d/DETAILS.md" ] || printf '  %s\n' "$d"
    done 2>/dev/null || true)
    [ -n "$missing" ] && say "a chantier folder has no DETAILS.md — its tasks have nowhere to be reasoned:
$missing"
    read_form=", task form"
  fi

  # An OPEN action outside the tracking doc. Declared files only — a checklist legitimately carries
  # empty boxes — and an archive only while UNCOMMITTED: a committed one is immutable, and ten of
  # them already hold the pattern. Why the marker and not a name: verify-workspace.md.
  # In the HEADER only: a pledge is made at the top. Anywhere else the literal is prose — the
  # tracking doc describing this very guard signed itself up, and it is the one file allowed work.
  pledged=$(cd "$ws" && git ls-files -- '*.md' | while read -r f; do
    head -10 "$f" 2>/dev/null | grep -qF -- '<!-- no-open-work -->' && printf '%s\n' "$f"
  done || true)
  closing=$(cd "$ws" && git ls-files --others --exclude-standard -- '*archives/*.md' 2>/dev/null || true)
  watched=$(printf '%s\n%s\n' "$pledged" "$closing" | sed '/^$/d' | sort -u)
  if [ -n "$watched" ]; then
    # fr-pattern: the documents it reads are French. A leftover DECLARES itself — an infinitive
    # opening a bullet would match half the prose (measured: verify-workspace.md).
    open_work=$(cd "$ws" && printf '%s\n' "$watched" | tr '\n' '\0' \
      | xargs -0 grep -nEi '(rest(e|ent) (encore )?à |^[[:space:]]*[-*] \[ \])' 2>/dev/null \
      | cut -c1-120 || true)
    [ -n "$open_work" ] && say "open work is sitting outside $(basename "${track:-the tracking doc}") — it belongs in it, or nowhere:
$open_work"
    read_pledge=", $(printf '%s\n' "$watched" | wc -l | tr -d ' ') file(s) pledging no open work"
  fi
fi

[ "$fail" = 0 ] && echo "✓ workspace: git, no remote, no secret tracked${read_gate:-}, ${systems:-0} tracking system(s)${read_backlog:+,${read_backlog}}${read_numbers:-}${read_form:-}${read_pledge:-} — looked for SUIVI/TRACKING/PROGRESS.md and $(echo "${OTHERS:-}" | sed 's|\([^ ]*\)|\1/|g; s| |, |g')${unlisted:+; also tracked, unrecognised —$unlisted — name it above if it is a tracking tool}${not_read:+; NOT read:$not_read}"
exit "$fail"
