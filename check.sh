#!/usr/bin/env bash

# Usage:  ./check.sh            everything
#         ./check.sh --commit   only what a commit can make say something new (see MODE below)
#         ./check.sh --house    ONLY the house checks — the gate a CI calls (see MODE below)
#         ./check.sh --report   the control journal, a DEV instrument: --on | --off | --reset

# Versions are NEVER hardcoded: read from ci.yml (+ requirements-ci.txt), cached under .ci-tools/.
# Local pins the VERSION and checks it via --version; CI additionally verifies the asset's SHA256.
set -euo pipefail
cd "$(dirname "$0")"

CI=.github/workflows/ci.yml
CACHE=.ci-tools
mkdir -p "$CACHE"
[ -f "$CI" ] || { echo "No $CI here — nothing to replay."; exit 0; }

# ── The control journal lives OUTSIDE every repository ────────────────────────────────────────
# Why there, why not named after this repository, and what a shared journal buys: the control
# matrix states it in full. XDG_STATE_HOME is the convention for data that persists between runs
# and that nobody would miss if it were deleted.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-controls"
JOURNAL="$STATE_DIR/controls-log.tsv"
JOURNAL_ON="$STATE_DIR/journal-on"
# Which project a line came from. `basename` alone is useless here: every repository of this shape
# is called `repo`, so the parent carries the name — `template/repo`, `<project>/repo`.
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT="$(basename "$(dirname "$root")")/$(basename "$root")"

MODE=full
case "${1:-}" in
  --commit) MODE=commit;;
  --house)  MODE=house;;
  --report) MODE=report;;
  # Answered here, before anything runs: this was the ONE tracked executable outside the sweep that
  # compares them, and its absence rested on a grep that had to be kept from matching a mention.
  --version) echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"; exit 0;;
esac

if [ "$MODE" = report ]; then
  J="$JOURNAL"
  mkdir -p "$STATE_DIR"
  case "${2:-}" in
    --on)  : > "$JOURNAL_ON"; echo "Control journal ON — recording to $J. Turn it off with: ./check.sh --report --off"; exit 0;;
    --off) rm -f "$JOURNAL_ON"; echo "Control journal OFF. The recording so far is kept in $J."; exit 0;;
    # The switch and the record are global, so a reset is too — and it says which projects it drops,
    # since a file shared by every project is not one to clear without looking.
    --reset)
      if [ -f "$J" ]; then
        echo "Clearing $(wc -l < "$J" | tr -d ' ') record(s), from: $(cut -f7 "$J" | sort -u | tr '\n' ' ')"
      fi
      rm -f "$J"; echo "Control journal cleared."; exit 0;;
  esac
  [ -f "$JOURNAL_ON" ] || echo "  (journal is OFF — showing what was recorded before. Switch on: ./check.sh --report --on)" >&2
  [ -f "$J" ] || { echo "No control has run while the journal was on. Switch it on: ./check.sh --report --on"; exit 0; }
  OUT=${3:-../workspace/docs/CONTROLES.md}
  # The timestamps below are those of the RECORDS, never of the reading — said to the reader in the
  # page itself, just below.
  STATE=off; [ -f "$JOURNAL_ON" ] && STATE=on
  python3 - "$J" "$OUT" "$STATE" "$PROJECT" <<'PY'
import sys, collections, pathlib, statistics
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
rows = [r for r in rows if len(r) >= 4]
# Filtered here (at read time, not write time) so one file answers both the per-project and the
# cross-project question. Records written before the column existed have no owner and are KEPT:
# dropping records to tidy a page is how a measurement quietly loses its base.
me = sys.argv[4] if len(sys.argv) > 4 else ""
others = sorted({r[6] for r in rows if len(r) > 6 and r[6] and r[6] != me})
rows = [r for r in rows if len(r) <= 6 or not r[6] or r[6] == me]
agg = collections.OrderedDict()
for r in rows:
    ts, mode, name, rc = r[0], r[1], r[2], r[3]
    ms, why = (r[4] if len(r) > 4 else ""), (r[5] if len(r) > 5 else "")
    a = agg.setdefault(name, {"runs": 0, "ko": 0, "skip": 0, "last": ts, "why": "", "ms": [], "modes": set()})
    a["last"] = ts; a["modes"].add(mode)
    if rc == "skip":
        a["skip"] += 1; a["gate"] = why
    else:
        a["runs"] += 1
        if ms.isdigit(): a["ms"].append(int(ms))
        if rc != "0": a["ko"] += 1; a["why"] = why or name

def med(v): return f"{statistics.median(v)/1000:.2f} s" if v else "—"
total_ms = sum(statistics.median(a["ms"]) for a in agg.values() if a["ms"])

recording = sys.argv[3] == "on"
status = ("🟢 **Recording is ON** — this page grows at every verdict."
          if recording else
          "🔴 **Recording is OFF — this page is FROZEN.** Nothing has been added since the newest "
          "record below, and nothing will be. Switch it back on: `./check.sh --report --on`.")

scope = (f"> 📓 **This page speaks for `{me}` alone.** The journal itself lives outside every "
         f"repository and is shared: it also holds {', '.join(f'`{o}`' for o in others)}, filtered "
         f"out here." if others else
         f"> 📓 **This page speaks for `{me}`.** The journal lives outside every repository and is "
         f"shared with any other project running these checks — none has written to it yet.")

if not rows:
    print(f"Nothing recorded for {me} yet — the journal holds only other projects. "
          f"Run ./check.sh with the journal on.")
    raise SystemExit(0)

out = ["# Controls — performance, and whether their gates actually fire", "",
       "> Written by `./check.sh` itself at every verdict.",
       "> A **development instrument**: `./check.sh --report --on | --off | --reset`.", "",
       status, "", scope, "",
       "> ⚠️ **The timestamps are those of the RECORDS, never of the reading.** Read alone, an old "
       "newest-record cannot tell *recording stopped* from *nothing has run* — which is why the "
       "line above states which one it is.", "",
       f"**{len(rows)} records**, **{len(agg)} controls**, "
       f"`{rows[0][0]}` → `{rows[-1][0]}`. Median time of the whole set, run one by one: "
       f"**{total_ms/1000:.2f} s** *(they run together, so the lot costs its slowest, not this sum)*.", "",
       "| Control | Fired | Skipped | Bit | Median | Slowest | Modes | Last | What it caught |",
       "|---|---:|---:|---:|---:|---:|---|---|---|"]
for name, a in sorted(agg.items(), key=lambda kv: -(statistics.median(kv[1]["ms"]) if kv[1]["ms"] else 0)):
    ko = f"**{a['ko']}**" if a["ko"] else "0"
    sk = f"{a['skip']}" if a["skip"] else "—"
    slow = f"{max(a['ms'])/1000:.2f} s" if a["ms"] else "—"
    out.append(f"| `{name}` | {a['runs']} | {sk} | {ko} | {med(a['ms'])} | {slow} | "
               f"{' '.join(sorted(a['modes']))} | {a['last'][11:19]} | {a['why'] or '—'} |")

# The reading that matters: a control that never fired. Its gate may simply never have opened.
never = [n for n, a in agg.items() if a["runs"] == 0]
out += ["", "## Gates"]
if never:
    out.append("🔴 **Never fired, only skipped** — the gate may never open: "
               + ", ".join(f"`{n}`" for n in never) + ".")
else:
    out.append("✅ Every control recorded here has fired at least once.")
out.append("*A control absent from this table has never run while the journal was on — "
           "a fact about this machine, not about the control.*")
p = pathlib.Path(sys.argv[2]); p.parent.mkdir(parents=True, exist_ok=True)
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("\n".join(out))
print(f"\n(written to {p})", file=sys.stderr)
PY
  exit 0
fi
changed=""
# The neighbouring workspace/ is a SEPARATE git repository, so a diff run here is blind to it —
# and two checks (verify-echo, verify-growth) read its prose. Without this, a SUIVI.md that
# doubles in size wakes nothing unless a .md happens to move here in the same commit.
[ "$MODE" = commit ] && changed=$( { git diff --name-only HEAD 2>/dev/null || true
                                     git -C ../workspace diff --name-only HEAD 2>/dev/null || true; } )
touched() { [ "$MODE" != commit ] || printf '%s\n' "$changed" | grep -qE "$1"; }

# WHERE the commit is being made, which git tells a hook only through variables that same hook must
# clear before calling this — so the caller states it, and repo/ is the default. The two checks that
# GENERATE a whole project answer about THIS tree: work in flight in the other repository cannot
# change their verdict, and its own commit is what judges it.
here=""
[ "$MODE" = commit ] && here=$(git -C "${CHECK_COMMIT_IN:-.}" diff --name-only HEAD 2>/dev/null || true)
touched_here() { [ "$MODE" != commit ] || printf '%s\n' "$here" | grep -qE "$1"; }
external() { [ "$MODE" != house ]; }

os=$(uname -s | tr '[:upper:]' '[:lower:]')          # darwin | linux
uarch=$(uname -m)
gl_arch=arm64; al_arch=arm64; osv_arch=arm64
[ "$uarch" = x86_64 ] && { gl_arch=x64; al_arch=amd64; osv_arch=amd64; }

fail=0

# 🔴 OFF unless switched ON. The switch is a witness file beside the journal: absent, journal()
# returns immediately and costs one file test.
journal() {   # <control> <rc|skip> <reason> [milliseconds]
  [ -f "$JOURNAL_ON" ] || return 0
  # The tools-ready line is not a control, it is this script reporting on itself.
  case "$1" in "ready under "*) return 0;; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$MODE" "$1" "$2" "${4:-}" "$3" "$PROJECT" >> "$JOURNAL"
}
# A skip recorded here, and a check simply absent from the journal, are two different facts —
# only one of them is fine.
skipped() { journal "$1" skip "$2"; }
note() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
LAST_MS=""
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; journal "$1" 0 "" "$LAST_MS"; LAST_MS=""; }
ko()   { printf '  \033[31m✗ %s\033[0m\n' "$1"; fail=1; journal "$1" 1 "$1" "$LAST_MS"; LAST_MS=""; }

# Replays one house check's captured output and returns its exit code. A missing capture is an
# ERROR, never a pass: a check that did not run must not read like a check that found nothing.
PAR="$CACHE/par"
reap() {
  [ -f "$PAR/$1.rc" ] || { echo "  (nothing captured for $1 — it never ran)"; return 1; }
  LAST_MS=$(cat "$PAR/$1.ms" 2>/dev/null || echo "")
  cat "$PAR/$1.out"
  local rc; rc=$(cat "$PAR/$1.rc")
  if [ "$rc" != 0 ] && grep -qE '^# blocking: no\b' "checks/$1.sh" 2>/dev/null; then
    printf '  \033[31m✗ %s declares `# blocking: no` and just exited %s — advisory is a claim about the EXIT CODE\033[0m\n' "$1" "$rc"
    fail=1
  fi
  return "$rc"
}

# timed() clocks a command OUTSIDE the parallel lot so LAST_MS is never a bare —.
# `|| _rc=$?` (never `; _rc=$?`) keeps this safe under set -e, recording the duration even on failure.
timed() {
  local _t0 _t1 _rc=0
  _t0=${EPOCHREALTIME/./}
  "$@" || _rc=$?
  _t1=${EPOCHREALTIME/./}
  [ -n "$_t0" ] && [ -n "$_t1" ] && LAST_MS=$(( (_t1 - _t0) / 1000 ))
  return "$_rc"
}

pin()   { grep -m1 "^[[:space:]]*$1:" "$CI" | awk '{print $2}' || true; }   # a `NAME: value` env from ci.yml (empty if absent)
in_ci() { grep -v '^[[:space:]]*#' "$CI" | grep -q -- "$1"; }        # does CI run this tool? (excluding comments)

# Pip versions file (zizmor/semgrep): the repo's if it exists, otherwise the template's.
reqfile=requirements-ci.txt
[ -f "$reqfile" ] || reqfile=templates/repo/requirements-ci.txt
# Zizmor config: the repo's, otherwise the shipped one (the template lints its own workflow with it).
zconfig=.github/zizmor.yml
[ -f "$zconfig" ] || zconfig=templates/repo/.github/zizmor.yml

ensure_gitleaks() {
  local tag="$1" v="${1#v}" bin="$CACHE/gitleaks"
  if [ -x "$bin" ] && "$bin" version 2>/dev/null | grep -q "$v"; then return; fi
  local f="gitleaks_${v}_${os}_${gl_arch}.tar.gz"
  curl -sSfL -o "$CACHE/$f" "https://github.com/gitleaks/gitleaks/releases/download/${tag}/${f}"
  tar -xzf "$CACHE/$f" -C "$CACHE" gitleaks; rm -f "$CACHE/$f"
}
ensure_actionlint() {
  local tag="$1" v="${1#v}" bin="$CACHE/actionlint"
  if [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -q "$v"; then return; fi
  local f="actionlint_${v}_${os}_${al_arch}.tar.gz"
  curl -sSfL -o "$CACHE/$f" "https://github.com/rhysd/actionlint/releases/download/${tag}/${f}"
  tar -xzf "$CACHE/$f" -C "$CACHE" actionlint; rm -f "$CACHE/$f"
}
ensure_osv() {
  local tag="$1" v="${1#v}" bin="$CACHE/osv-scanner"
  if [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -q "$v"; then return; fi
  curl -sSfL -o "$bin" "https://github.com/google/osv-scanner/releases/download/${tag}/osv-scanner_${os}_${osv_arch}"
  chmod +x "$bin"
}
# Reinstalls only when a version is missing on disk — not via --version (~1.5 s/run, and it would
# not catch a moved project leaving the venv's absolute shebangs dangling). pip's shebang
# interpreter is checked instead, and the venv rebuilt if broken.
ensure_venv() {
  local need=0 spec tool ver interp
  if [ -f "$CACHE/venv/bin/pip" ]; then
    interp=$(head -1 "$CACHE/venv/bin/pip"); interp="${interp#\#!}"; interp="${interp%% *}"
    [ -x "$interp" ] || { echo "  venv points at a path that no longer exists — rebuilding"; rm -rf "$CACHE/venv"; }
  fi
  [ -d "$CACHE/venv" ] || { python3 -m venv "$CACHE/venv"; need=1; }
  for spec in "$@"; do
    tool="${spec%%==*}"; ver="${spec#*==}"
    if [ ! -x "$CACHE/venv/bin/$tool" ] ||
       ! compgen -G "$CACHE/venv/lib/python*/site-packages/${tool}-${ver}.dist-info" >/dev/null; then
      need=1
    fi
  done
  [ "$need" = 0 ] && return
  "$CACHE/venv/bin/pip" install --quiet --upgrade pip >/dev/null
  "$CACHE/venv/bin/pip" install --quiet "$@"
}

GITLEAKS_VERSION=$(pin GITLEAKS_VERSION)
ACTIONLINT_VERSION=$(pin ACTIONLINT_VERSION)
OSV_VERSION=$(pin OSV_VERSION)
ZIZMOR_SPEC=$(grep -m1 '^zizmor==' "$reqfile" 2>/dev/null || true)
SEMGREP_SPEC=$(grep -m1 '^semgrep==' "$reqfile" 2>/dev/null || true)
# The WHOLE version, not up to the first dot: `renovate@43` is a RANGE, and npx would then resolve
# whatever 43.x npm serves today instead of the version the CI pins — the one thing this file exists
# to guarantee.
RENOVATE_PKG=$(grep -m1 -oE 'renovate@[0-9][^[:space:]"'"'"']*' "$CI" | head -1 || true)
[ -n "$RENOVATE_PKG" ] || RENOVATE_PKG=renovate@44.14.10

if external; then
  note "Pinned tools (auto-detected from $CI)"
  [ -n "$GITLEAKS_VERSION" ]   && ensure_gitleaks "$GITLEAKS_VERSION"
  [ -n "$ACTIONLINT_VERSION" ] && ensure_actionlint "$ACTIONLINT_VERSION"
  if in_ci osv-scanner && [ -n "$OSV_VERSION" ]; then ensure_osv "$OSV_VERSION"; fi
  venv_specs=()
  if in_ci zizmor  && [ -n "$ZIZMOR_SPEC" ];  then venv_specs+=("$ZIZMOR_SPEC");  fi
  if in_ci semgrep && [ -n "$SEMGREP_SPEC" ]; then venv_specs+=("$SEMGREP_SPEC"); fi
  [ "${#venv_specs[@]}" -gt 0 ] && ensure_venv "${venv_specs[@]}"
  ok "ready under $CACHE/"
else
  note "House checks only (--house) — the external tools are the CI's own steps"
fi

# House checks read the tree and write nothing: they all start together here, so their sum is their
# slowest, running under the external tools rather than after. Each capture is replayed later by the
# block that owns it, keeping report order stable.
rm -rf "$PAR"; mkdir -p "$PAR"
for s in checks/verify-*.sh; do
  grep -qE '^# hook: ' "$s" && continue
  # The two that GENERATE a project run in the lot like the others: each works inside its own
  # `mktemp -d`, and the nested `check.sh` writes to the generated project's own `.ci-tools/`
  # (CACHE is relative), so nothing is shared. Run one after the other they dominate the gate's
  # wall clock, which is the only reason they belong in the lot (durations: repo-controls.md).
  case "$s" in
    *verify-echo.sh)          touched '\.md$' || continue;;
    *verify-growth.sh)        touched '\.md$' || continue;;
    *verify-comment-drift.sh) touched '\.sh$' || continue;;
    *verify-travel.sh)          touched_here '^templates/|^checks/|^check\.sh$|^init-project\.sh$' || continue;;
    *verify-generated-green.sh) touched_here '^templates/|^checks/|^check\.sh$|^init-project\.sh$|^docs/code/' || continue;;
  esac
  [ -x "$s" ] || continue
  n=$(basename "$s" .sh)
  # `EPOCHREALTIME` (bash 5) rather than `date +%s%3N`: that format is GNU, and BSD `date` returns
  # the literal `%3N` WITHOUT failing, so a `||` fallback never fires and every duration read zero.
  # No subprocess either — an instrument that costs a fork per measurement measures itself.

  # `set +e` is what makes the capture work at all: this file runs under `set -e`, which the
  # subshell inherits, so a check exiting non-zero killed it BEFORE the .rc was written. A missing
  # .rc then reads as "it never ran", announced instead of the check's own error message — which
  # stayed in the .out and was never printed, making every failure look alike.
  ( set +e
    _t0=${EPOCHREALTIME/./}
    "./$s" >"$PAR/$n.out" 2>&1; _rc=$?
    _t1=${EPOCHREALTIME/./}
    echo $_rc >"$PAR/$n.rc"
    if [ -n "$_t0" ] && [ -n "$_t1" ]; then echo $(( (_t1 - _t0) / 1000 )) >"$PAR/$n.ms"; fi ) &
done

if external && in_ci shellcheck && touched '\.sh$|^\.githooks'; then
  note "shellcheck — shell scripts"
  targets=()
  while IFS= read -r f; do targets+=("$f"); done < <(
    find . -type f -name '*.sh' -not -path './.ci-tools/*' -not -path './.git/*' -not -path './node_modules/*')
  # A hook carries no extension, and there is more than one hooks directory: the gate that arms the
  # neighbour is a second one. Naming a single directory left it unlinted here AND in the CI.
  while IFS= read -r f; do targets+=("$f"); done < <(
    find . -type f -path './.githooks*' -not -path './.git/*')
  if [ "${#targets[@]}" -eq 0 ]; then ok "no shell scripts"
  elif ! command -v shellcheck >/dev/null 2>&1; then ko "shellcheck missing — 'brew install shellcheck'"
  elif timed shellcheck -S warning "${targets[@]}"; then ok "shellcheck"; else ko "shellcheck"; fi
fi

if external && in_ci actionlint && [ -d .github/workflows ] && touched '^\.github/workflows/'; then
  note "actionlint — workflows"
  if timed "$CACHE/actionlint" -color; then ok "actionlint"; else ko "actionlint"; fi
fi

# Its CONFIG counts as much as the workflows: tightening or loosening a rule in
# templates/repo/.github/zizmor.yml changes the verdict, and that path is not under
# .github/workflows/ — so gating on the workflows alone left the config unwatched.
if external && in_ci zizmor && [ -d .github/workflows ] && touched '^\.github/workflows/|zizmor\.yml$'; then
  note "zizmor — workflows (config $zconfig)"
  if timed "$CACHE/venv/bin/zizmor" --persona regular --config "$zconfig" .github/workflows/; then ok "zizmor"; else ko "zizmor"; fi
fi

# `full` only, for semgrep and osv below: their verdict comes from an EXTERNAL base queried online,
# never from the tree, so a commit cannot make either say anything new. The rhythm is the matrix's.
if in_ci semgrep && [ "$MODE" = full ]; then
  note "semgrep — the code (curated packs)"
  if timed "$CACHE/venv/bin/semgrep" scan --error --quiet --metrics=off --exclude=.github \
       --config p/security-audit --config p/owasp-top-ten .; then ok "semgrep"; else ko "semgrep"; fi
fi

if in_ci osv-scanner && [ "$MODE" = full ]; then
  note "osv-scanner — dependencies (all manifests)"
  if timed "$CACHE/osv-scanner" scan source -r . --allow-no-lockfiles; then ok "osv"; else ko "osv"; fi
fi

# Scope is what's NOT pushed yet (flat cost whatever the repo's size) — and it catches a secret
# from a local commit whose file has since been deleted, which scanning the last commit alone misses.
if external && [ -n "$GITLEAKS_VERSION" ]; then
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ "$MODE" = commit ] && [ -n "$upstream" ]; then
    note "gitleaks — what is not on $upstream yet"
    if timed "$CACHE/gitleaks" git --no-banner --redact --log-opts="$upstream..HEAD"; then ok "gitleaks"; else ko "gitleaks"; fi
  else
    note "gitleaks — full history"
    if timed "$CACHE/gitleaks" git --no-banner --redact; then ok "gitleaks"; else ko "gitleaks"; fi
  fi
fi

# checks/verify-checksums.sh — whenever it exists (this repo only: no generated project ships doc
# pairs like docs/X.md + hand-authored docs/X.html). Guards against the .html drifting from its
# source .md; silent no-op elsewhere.
wait || true      # the house checks started above; from here their results are read back

if [ -x checks/verify-checksums.sh ]; then
  note "checks/verify-checksums.sh — .md/.html checksum guard"
  if reap verify-checksums; then ok "doc checksums"; else ko "doc checksums"; fi
fi

# verify-secret-blindspots.sh — gitleaks looks for secret-SHAPED strings, never for a file CALLED
# .env. An empty one passes it, gets committed, and is filled in at the next commit.
if [ -x checks/verify-secret-blindspots.sh ]; then
  note "verify-secret-blindspots.sh — where a secret sits that gitleaks never reads"
  if reap verify-secret-blindspots; then ok "no secret in a blind spot"; else ko "secret in a blind spot"; fi
fi

# verify-private-names.sh — the other half of that blind spot: a NAME leaks nothing token-shaped.
if [ -x checks/verify-private-names.sh ]; then
  note "verify-private-names.sh — private names in a public repository"
  if reap verify-private-names; then ok "no private name published"; else ko "private name published"; fi
fi

if [ -x checks/verify-echo.sh ]; then
  note "verify-echo.sh — the same fact stated twice, in different words"
  if touched '\.md$'; then
    if reap verify-echo; then ok "no paragraph restates another"; else ko "a paragraph restates another"; fi
  else echo "  (skipped — no .md changed in this commit)"; skipped "verify-echo" "no .md changed"; fi
fi

if [ -x checks/verify-growth.sh ]; then
  note "verify-growth.sh — curated documents that only grow"
  if touched '\.md$'; then
    if reap verify-growth; then ok "no curated document only grows"; else ko "a curated document only grows"; fi
  else echo "  (skipped — no .md changed in this commit)"; skipped "verify-growth" "no .md changed"; fi
fi

if [ -x checks/verify-comment-drift.sh ]; then
  note "verify-comment-drift.sh — a comment outgrowing its code"
  if touched '\.sh$'; then
    if reap verify-comment-drift; then ok "no comment outgrowing its code"; else ko "a comment outgrows its code"; fi
  else echo "  (skipped — no .sh changed in this commit)"; skipped "verify-comment-drift" "no .sh changed"; fi
fi

if [ -x checks/verify-dropped-comment.sh ]; then
  note "verify-dropped-comment.sh — a comment block deleted with nowhere to say where it went"
  if touched '\.sh$'; then
    if reap verify-dropped-comment; then ok "deleted comments accounted for"; else ko "a comment block vanished"; fi
  else echo "  (skipped — no .sh changed in this commit)"; skipped "verify-dropped-comment" "no .sh changed"; fi
fi

if [ -x checks/verify-changelog.sh ]; then
  note "verify-changelog.sh — a user-visible change with no CHANGELOG line"
  if reap verify-changelog; then ok "changelog"; else ko "changelog"; fi
fi

# verify-commit-form.sh — the same file the `commit-msg` hook hands its message to, run here on the
# branch's commits. The hook is bypassable and invisible server-side; this is what the CI sees.
if [ -x checks/verify-commit-form.sh ]; then
  note "verify-commit-form.sh — a commit subject out of form"
  if reap verify-commit-form; then ok "commit subjects"; else ko "a commit subject is out of form"; fi
fi

# verify-links.sh — a dead relative link is invisible: nothing renders an error, the reader just
# lands nowhere. This repo runs on pointers, so a broken one turns "one source" back into none.
if [ -x checks/verify-links.sh ]; then
  note "verify-links.sh — dead relative links (both repos)"
  if reap verify-links; then ok "links"; else ko "links"; fi
fi

# verify-workspace.sh — the neighbouring workspace/ has NO remote on purpose, which is exactly what
# makes it invisible: no diff-vs-origin, no CI, and this script runs in repo/ without looking beside it.
if [ -x checks/verify-stage-closure.sh ]; then
  note "verify-stage-closure.sh — a stage closed without leaving its archive (advisory)"
  if reap verify-stage-closure; then ok "stage closure"; else ko "stage closure"; fi
fi

if [ -x checks/verify-workspace.sh ]; then
  note "verify-workspace.sh — the neighbouring workspace (no remote, no secret tracked)"
  if reap verify-workspace; then ok "workspace"; else ko "workspace"; fi
fi

# verify-narrative.sh — travels with check.sh, like verify-tone.sh: METHODE holds for every project
# this repo generates, and a generated project's code carries comments too.
if [ -x checks/verify-narrative.sh ]; then
  note "verify-narrative.sh — dated narrative in code comments"
  if reap verify-narrative; then ok "no dated narrative"; else ko "dated narrative"; fi
fi

# verify-memories.sh — the only check whose subject lives OUTSIDE the repo, so the CI structurally
# cannot run it: no diff, no workflow, nothing else watches that place. Silent where there are none.
if [ -x checks/verify-memories.sh ]; then
  note "verify-memories.sh — index and links of the memories"
  if reap verify-memories; then ok "memories"; else ko "memories"; fi
fi

# verify-do-not-break.sh — the invariants of AGENTS.md, "Do not break". Two of its three targets
# sit outside the repository, like the memories above; the third one, the force-added files, is
# inside and so it still says something under the CI.
if [ -x checks/verify-do-not-break.sh ]; then
  note "verify-do-not-break.sh — invariants whose breakage is silent"
  if reap verify-do-not-break; then ok "nothing unplugged"; else ko "something unplugged"; fi
fi

# verify-checks-wiring.sh — the loop above started it like the others, and NOTHING read its verdict
# back: a check deleted from the tree left this lot green while the CI, which runs the same file,
# went red. The one promise this script makes is local == github, and the guard of that very wiring
# was the one it dropped. It cannot catch this class itself — it compares the table against ci.yml
# and init-project.sh, never against check.sh.
if [ -x checks/verify-checks-wiring.sh ]; then
  note "verify-checks-wiring.sh — every check declared, and wired as declared"
  if reap verify-checks-wiring; then ok "checks wired"; else ko "a check is not wired as declared"; fi
fi

if [ -x checks/verify-travel.sh ] && touched_here '^templates/|^checks/|^check\.sh$|^init-project\.sh$'; then
  note "verify-travel.sh — paths that die where the file lands"
  if reap verify-travel; then ok "travelling paths"; else ko "travelling paths"; fi
fi

# Same trigger, and it also generates — but it asks the other question: not "does this path
# resolve there?", but "does the DOOR pass there?". Three defects hid behind that gap at once,
# including two checks that exited non-zero without printing a single line.
if [ -x checks/verify-generated-green.sh ] && touched_here '^templates/|^checks/|^check\.sh$|^init-project\.sh$|^docs/code/'; then
  note "verify-generated-green.sh — a generated project's own door"
  if reap verify-generated-green; then ok "generated project born green"; else ko "generated project born red"; fi
fi

# verify-version.sh — same shape: present only in this repo, silent no-op in a generated project.
if [ -x checks/verify-version.sh ]; then
  note "verify-version.sh — version coherence"
  if reap verify-version; then ok "version"; else ko "version"; fi
fi

renovate_files=()
while IFS= read -r f; do renovate_files+=("$f"); done < <(
  find . -type f -name 'renovate.json' -not -path './.ci-tools/*' -not -path './.git/*' -not -path './node_modules/*')
# The pinned renovate version is read from ci.yml, and a bump can flip a valid config to
# invalid or back — so the workflow carrying the pin wakes the validator too.
if external && [ "${#renovate_files[@]}" -gt 0 ] && touched 'renovate\.json$|^\.github/workflows/ci\.yml$'; then
  note "renovate-config-validator — ${#renovate_files[@]} config(s)"
  # ONE npx call for all configs: npx reloads the renovate package on every invocation, and the
  # validator takes a file list and still names each file it rejects.
  if timed npx --yes --package "$RENOVATE_PKG" renovate-config-validator "${renovate_files[@]}" >/dev/null 2>&1
  then ok "renovate configs valid"; else ko "renovate config invalid"; fi
fi

if [ -x checks/verify-tone.sh ]; then
  note "verify-tone.sh — second person (standard §1)"
  if reap verify-tone; then ok "no second person"; else ko "second person in versioned content"; fi
fi

if [ -x checks/verify-language.sh ]; then
  note "verify-language.sh — French in published content"
  if reap verify-language; then ok "no French in published content"; else ko "French in published content"; fi
fi

if [ -x checks/verify-line-form.sh ]; then
  note "verify-line-form.sh — a sentence cut across two lines"
  if reap verify-line-form; then ok "no sentence cut across two lines"; else ko "a sentence is cut across two lines"; fi
fi

echo
if [ "$fail" = 0 ]; then
  printf '\033[32m✓ local == github: all pass.\033[0m\n'
else
  printf '\033[31m✗ gaps above — CI will block on push.\033[0m\n'; exit 1
fi
