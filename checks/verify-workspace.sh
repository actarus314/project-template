#!/usr/bin/env bash
# blocking: yes   rule: tracking-doc.md   tags: 24   (what this does with a verdict; compared to the control table AND to its real exit code)
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
# since this is the one check whose whole reason to exist is looking over there.
[ -d "$ws" ] || { echo "  (no $ws beside this repo — nothing to check)"; exit 0; }

fail=0
not_read=""
# Each rule carries a TAG, and it is what reaches the journal: nineteen rules under one control name
# left no way to know which of them ever bit. Absent CHECK_TAGS — run by hand, or by the hook — the
# tag goes nowhere and the message is unchanged.
tag() { [ -n "${CHECK_TAGS:-}" ] && printf '%s\n' "$1" >>"$CHECK_TAGS"; return 0; }
say() { tag "$1"; echo "✗ workspace/: $2" >&2; fail=1; }
# A verdict on the NEIGHBOUR's local config, which no commit here can repair and which this
# repository never receives through a diff — blocking on it stops the work in repo/ for a fault
# sitting next door, and the exact command to repair it is in the message.
warn() { echo "⚠ workspace/: $1" >&2; }

if ! git -C "$ws" rev-parse --git-dir >/dev/null 2>&1; then
  say "no-git" "not a git repository — a plain folder has no history and no safety net"
else
  remotes=$(git -C "$ws" remote 2>/dev/null || true)
  if [ -n "$remotes" ]; then
    say "has-remote" "HAS A REMOTE ($(echo "$remotes" | tr '\n' ' ')) — it carries private names; this must never be pushed"
  fi

  # A tracked NAME betrays, not the content — gitleaks already scans content (verify-workspace.md).
  tracked=$(git -C "$ws" ls-files 2>/dev/null | grep -iE '(^|/)(secrets?|\.env)(\.[a-z]+)?$' || true)
  [ -n "$tracked" ] && say "secret-tracked" "tracks a secret-named file: $(echo "$tracked" | tr '\n' ' ')"

  # The workspace's own gate. The armed path is RESOLVED before being judged, because each way of
  # getting it wrong is silent on its own: an unset core.hooksPath runs the default hooks (there are
  # none), a path pointing nowhere makes git run nothing at all, and a path pointing at ANOTHER hooks
  # directory runs someone else's hook while this gate stays absent. A LOCAL config travels through
  # no diff, so a regenerated project arrives here unarmed — hence the exact command in the message.
  gate_dir="$PWD/.githooks-workspace"   # this repository's own, whatever the directory is named
  if [ ! -f "$gate_dir/pre-commit" ]; then
    not_read="$not_read .githooks-workspace/pre-commit(absent here — nothing to arm)"
  elif [ ! -x "$gate_dir/pre-commit" ]; then
    say "gate-not-armed" "$gate_dir/pre-commit is not executable — git ignores a hook without that bit, and says nothing"
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
    say "two-tracking-systems" "$systems tracking systems compete (${n} doc(s)${found_others:+, plus${found_others}}) — METHODE allows one, and the stale one gets read first"

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
      /^#+ / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }
      inside && /^\|/ && /\|[[:space:]]*(✅|✔|☑|~~|LIVRÉ|LIVRE|DONE|FAIT|TERMINÉ|TERMINE|CLOS)/ { print NR ": " substr($0, 1, 72) }   # fr-pattern: the doc it reads is French
    ' "$track" || true)
    if [ -n "$stale" ]; then
      say "closed-in-open-work" "closed items are sitting in the open-work section of $(basename "$track") — they belong in the state section or an archive:
$stale"
    fi
    read_backlog=" backlog hygiene"

    # A chantier number is never reused — an archive reference has to keep resolving, and one has
    # already stopped: two numbers freed in July were handed out again in August, before the rule
    # existed. Read from the FIRST cell of a table row, never from prose: a number in a sentence is
    # a reference, not a claim to the number. Why only same-section duplicates: verify-workspace.md.
    nums=$(awk '
      /^#+ / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }   # fr-pattern: the doc it reads is French
      inside && /^\|[[:space:]]*(▶[[:space:]]*)?\*\*[0-9]/ {
        if (match($0, /\*\*[0-9]+(\.[0-9]+)?\*\*/)) print substr($0, RSTART + 2, RLENGTH - 4)
      }' "$track" || true)
    dup=$(printf '%s\n' "$nums" | sed '/^$/d' | sort | uniq -d)
    if [ -n "$dup" ]; then
      say "number-reused" "two open chantiers share a number in $(basename "$track") — a number is never reused, or an archive pointer stops resolving:
$(printf '%s\n' "$dup" | sed 's/^/  /')"
    fi
    # The CLOSED numbers, read from the archive folder prefixes — the declaration this half was
    # missing, and the reason it could only compare open rows to each other. `000` names a folder
    # that predates the numbering and claims nothing, so it drops out.
    closed=$(cd "$ws" && ls -d archives/*/ 2>/dev/null | while read -r d; do
      b=${d#archives/}; printf '%s\n' "${b%%--*}" | tr '-' '\n'
    done | sed 's/^0*//' | grep -v '^$' | sort -u || true)
    reused=$(printf '%s\n' "$nums" | sed '/^$/d' | sort -u | comm -12 - <(printf '%s\n' "$closed") || true)
    if [ -n "$reused" ]; then
      say "number-reused" "an open chantier reuses a number an archive already closed — a pointer written today stops resolving:
$(printf '%s\n' "$reused" | sed 's/^/  /')"
    fi
    read_numbers=", $(printf '%s\n' "$nums" | sed '/^$/d' | sort -u | wc -l | tr -d ' ') open chantier number(s) against $(printf '%s\n' "$closed" | sed '/^$/d' | wc -l | tr -d ' ') closed in archive prefixes"

    # The FORM of a row and of a task, each rule binary. A row has FOUR columns — one missing pipe
    # desynchronises every field, and the task past it is judged by nothing at all. A task opens on a
    # mark AND a number, then an infinitive verb — recognised on the NUMBER, or a missing mark could
    # never be refused; it holds no link, no more than 72 characters — the
    # commit-subject limit, a subject and a task being the same object — and, while still OPEN, no
    # COUNT of what it has to treat. What is NOT here is "no retelling", a judgement. Why: verify-workspace.md.
    bad=$(awk -F'|' '
      /^#+ / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }   # fr-pattern: the doc it reads is French
      inside && /^\|[[:space:]]*(▶[[:space:]]*)?\*\*[0-9]/ {
        tail = $NF; gsub(/[[:space:]]/, "", tail)
        if (NF != 6 || tail != "") { print "  not four columns: " substr($2, 1, 20); next }
        n = split($4, seg, "<br>")
        for (i = 1; i <= n; i++) {
          s = seg[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
          if (s == "") continue                            # a stray <br>: nothing was written there
          mark = (s ~ /^(✅|⬜)/)
          num = (s ~ /^(✅|⬜)?[[:space:]]*\*\*[0-9]+\.[0-9]+\*\*/)
          if (!mark && !num) {
            if (i == 1) continue                           # only the FIRST segment may be a label
            print "  not a task: " substr(s,1,60); continue
          }
          if (!mark) { print "  unmarked: " substr(s,1,60); continue }
          open = (s ~ /^⬜/)
          t = s; sub(/^(✅|⬜)[[:space:]]*/, "", t)
          if (t !~ /^\*\*[0-9]+\.[0-9]+\*\*/) { print "  unnumbered: " substr(s,1,60); continue }
          sub(/^\*\*[0-9]+\.[0-9]+\*\*[[:space:]]*/, "", t)
          sub(/^\*\*[^*]+\*\*[[:space:]]*:[[:space:]]*/, "", t)   # an owner prefix is not the verb
          if (t ~ /\]\(/) print "  holds a link: " substr(t,1,50)
          bare = t; gsub(/\*|`|\*\*/, "", bare)
          if (length(bare) > 72) print "  " length(bare) " char.: " substr(bare,1,50)
          w = t; sub(/[[:space:]].*$/, "", w); gsub(/\*|`/, "", w)
          if (w !~ /(er|ir|re|oir)$/) print "  not an infinitive: " w
          # fr-pattern: a definite article before a number names a SET of objects to treat, which
          # can be split; a bare number is a threshold, which cannot. A ticked task keeps its count.
          if (open && bare ~ /(les|des|ces|ses) ([0-9]+|deux|trois|quatre|cinq|six|sept|huit|neuf|dix|onze|douze) /)
            print "  holds a count, so it can be split: " substr(bare,1,50)
        }
      }' "$track" || true)
    if [ -n "$bad" ]; then
      # EIGHT rules answer under one message, and the journal would credit them all to one name.
      # The tag comes from what the awk above printed — the wording IS the discriminator.
      case "$bad" in *"not four columns"*)     tag four-columns;; esac
      case "$bad" in *"unnumbered"*)           tag task-unnumbered;; esac
      case "$bad" in *"unmarked"*)             tag task-unmarked;; esac
      case "$bad" in *"not a task"*)           tag segment-not-a-task;; esac
      case "$bad" in *"holds a link"*)         tag task-holds-link;; esac
      case "$bad" in *" char.:"*)              tag task-too-long;; esac
      case "$bad" in *"not an infinitive"*)    tag task-not-infinitive;; esac
      case "$bad" in *"holds a count"*)        tag task-holds-count;; esac
      say "task-form" "a row or a task is out of form in $(basename "$track") — four columns; a task carries its state mark and its number, opens on an infinitive, holds no link, no count, at most 72 characters; only a cell's first segment may be a label:
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
    [ -n "$missing" ] && say "no-details-file" "a chantier folder has no DETAILS.md — its tasks have nowhere to be reasoned:
$missing"
    # The detail column carries a LINK, or the DASH that declares there is nothing to point at yet.
    # A frozen chantier has no folder, and an empty one invented for the rule reads as a lost folder.
    nodetail=$(awk -F'|' '
      /^#+ / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }   # fr-pattern: the doc it reads is French
      inside && /^\|[[:space:]]*(▶[[:space:]]*)?\*\*[0-9]/ {
        d = $5; gsub(/^[[:space:]]+|[[:space:]]+$/, "", d)
        if (d !~ /\]\(/ && d != "—") print "  " substr($2, 1, 20) " → " substr(d, 1, 40)
      }' "$track" || true)
    if [ -n "$nodetail" ]; then
      say "detail-column" "a chantier row points nowhere in $(basename "$track") — a link, or the dash saying there is nothing yet:
$nodetail"
    fi

    tasks=$(awk -F'|' '
      /^#+ / { inside = ($0 ~ /Ce qui reste|What (is )?left|Remaining/) ? 1 : 0; next }   # fr-pattern: the doc it reads is French
      inside && /^\|[[:space:]]*(▶[[:space:]]*)?\*\*[0-9]/ {
        n = split($4, seg, "<br>")
        for (i = 1; i <= n; i++) if (match(seg[i], /\*\*[0-9]+\.[0-9]+\*\*/)) print substr(seg[i], RSTART + 2, RLENGTH - 4)
      }' "$track" | sort -u || true)

    # A DETAILS.md reasons the tracking doc's tasks, so it names ONLY numbers that doc still carries
    # — a task deleted there leaves a section reasoning nothing, and a renumbering leaves it lying.
    # Read from the START of a heading: further in, a number is a citation (`arXiv:2603.00539`).
    cited=$(cd "$ws" && for f in WIP/*/DETAILS.md; do
      [ -f "$f" ] || continue
      awk -v f="$f" '
          /^## / {
          t = substr($0, 4)
          while (match(t, /^[0-9]+\.[0-9]+/)) {
            print substr(t, 1, RLENGTH) " " f
            t = substr(t, RLENGTH + 1)
            if (t ~ /^[[:space:]]*·/) sub(/^[[:space:]]*·[[:space:]]*/, "", t); else break
          }
        }' "$f"
    done || true)
    orphan=$(printf '%s\n' "$cited" | sed '/^$/d' | while read -r n f; do
      printf '%s\n' "$tasks" | grep -qxF "$n" || printf '  %s reasoned in %s\n' "$n" "$f"
    done || true)
    if [ -n "$orphan" ]; then
      say "orphan-task-section" "a DETAILS.md reasons a task the tracking doc does not carry — it is a second backlog, and the stale one gets read first:
$orphan"
    fi
    read_form=", task form, detail column, $(printf '%s\n' "$cited" | sed '/^$/d' | wc -l | tr -d ' ') reasoned task(s)"
  fi

  # A folder holding nothing is worse than none: it reads as a folder something was lost from.
  # And every folder is prefixed with the chantier number it serves, on three digits, so a listing
  # sorts by chantier — `000` where the number is impossible, which the July archives predate.
  # Emptiness is asked of GIT, not of the disk: a `.DS_Store` the Finder drops is ignored by the
  # neighbour and invisible to a commit, yet it makes an emptied folder look inhabited.
  empty=$(cd "$ws" && for d in WIP/*/; do
    [ -d "$d" ] || continue
    git ls-files --cached --others --exclude-standard -- "$d" 2>/dev/null | grep -q . || printf '  %s\n' "$d"
  done || true)
  [ -n "$empty" ] && say "empty-wip-folder" "a WIP folder holds nothing — it reads as one something disappeared from:
$empty"
  unprefixed=$(cd "$ws" && for d in WIP/*/ archives/*/; do
    [ -d "$d" ] || continue
    b=${d%/}; b=${b##*/}
    printf '%s' "$b" | grep -qE '^[0-9]{3}(-[0-9]{3})*--' || printf '  %s\n' "$d"
  done || true)
  [ -n "$unprefixed" ] && say "unprefixed-folder" "a stage folder carries no chantier number — three digits, then '--':
$unprefixed"
  # `|| true`: a workspace with neither directory — every generated one — makes `ls` fail, and
  # pipefail would then kill this script with no verdict at all, which is how it was caught.
  read_folders=", $(cd "$ws" && ls -d WIP/*/ archives/*/ 2>/dev/null | wc -l | tr -d ' ' || true) stage folder(s) named and non-empty"

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
    # A leftover DECLARES itself, and it declares itself with the MARK the tracking doc gives a task.
    # A turn of phrase is met inside a quotation as readily as inside an instruction (verify-workspace.md).
    open_work=$(cd "$ws" && printf '%s\n' "$watched" | tr '\n' '\0' \
      | xargs -0 grep -nE '(⬜|^[[:space:]]*[-*] \[ \])' 2>/dev/null \
      | cut -c1-120 || true)
    [ -n "$open_work" ] && say "open-work-outside" "open work is sitting outside $(basename "${track:-the tracking doc}") — it belongs in it, or nowhere:
$open_work"
    read_pledge=", $(printf '%s\n' "$watched" | wc -l | tr -d ' ') file(s) pledging no open work"
  fi

  # A PLAN prescribes one stage and belongs to the session that runs it: kept here it carries a state
  # the tracking doc already owns, and a why the stage's detail file already owns. Recognised by the
  # header the plan skill stamps on every plan it writes — a literal, so nothing here judges what a
  # plan is. HEAD block only: further down, those same words are prose ABOUT a plan. Archives are
  # excluded as above — one already holds the pattern, and an archive is immutable.
  plans=$(cd "$ws" && git ls-files -- '*.md' | grep -v '^archives/' || true)
  planned=$(cd "$ws" && printf '%s\n' "$plans" | sed '/^$/d' | while read -r f; do
    head -12 "$f" 2>/dev/null | grep -qF -- 'REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development' \
      && printf '  %s\n' "$f"
  done || true)
  [ -n "$planned" ] && say "plan-in-workspace" "a plan document sits in the workspace — it lives with the session that runs it, and its tasks belong in $(basename "${track:-the tracking doc}"):
$planned"
  read_plans=", $(printf '%s\n' "$plans" | sed '/^$/d' | wc -l | tr -d ' ') file(s) read for a plan header"

  # The process recalls the rules it applies and points at where each one lives. A rule document
  # NAMED there and absent from that recall leaves a reader with no way back to it. The list of rule
  # documents is read from the repository, never held here: one written down goes stale on the day a
  # document is added. Recognising a RULE would be a judgement — a named DOCUMENT is not.
  recall=$ws/process/REGLES.md
  if [ -f "$recall" ]; then
    missing_rule_doc=""
    for d in docs/*.md AGENTS.md; do
      b=$(basename "$d")
      case "$b" in README.md) continue;; esac
      # The BARE name, extension or not: the corpus writes `METHODE` far more often than the file
      # name, and a rule keyed on the extension would read a corpus nobody writes.
      n=${b%.md}
      grep -qF -- "$n" "$recall" && continue
      named=0
      for f in "$ws"/process/*.md; do
        [ -f "$f" ] || continue
        case "$f" in *REGLES.md) continue;; esac
        grep -qF -- "$n" "$f" && { named=1; break; }
      done
      [ "$named" = 1 ] || continue
      missing_rule_doc="$missing_rule_doc $b"
    done
    [ -n "$missing_rule_doc" ] && say "rule-doc-not-recalled" "a rule document the process names is missing from its recall ($(basename "$recall")) —$missing_rule_doc"
    read_recall=", rule recall covers the document(s) the process names"
  fi
fi

[ "$fail" = 0 ] && echo "✓ workspace: git, no remote, no secret tracked${read_gate:-}, ${systems:-0} tracking system(s)${read_backlog:+,${read_backlog}}${read_numbers:-}${read_form:-}${read_folders:-}${read_pledge:-}${read_plans:-}${read_recall:-} — looked for SUIVI/TRACKING/PROGRESS.md and $(echo "${OTHERS:-}" | sed 's|\([^ ]*\)|\1/|g; s| |, |g')${unlisted:+; also tracked, unrecognised —$unlisted — name it above if it is a tracking tool}${not_read:+; NOT read:$not_read}"
exit "$fail"
