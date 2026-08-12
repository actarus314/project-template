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

[ "$fail" = 0 ] && echo "✓ workspace: git, no remote, no secret tracked${read_gate:-}, ${systems:-0} tracking system(s)${read_backlog:+,${read_backlog}}${read_pledge:-} — looked for SUIVI/TRACKING/PROGRESS.md and $(echo "${OTHERS:-}" | sed 's|\([^ ]*\)|\1/|g; s| |, |g')${unlisted:+; also tracked, unrecognised —$unlisted — name it above if it is a tracking tool}${not_read:+; NOT read:$not_read}"
exit "$fail"
