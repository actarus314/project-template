#!/usr/bin/env bash
# Replays THIS repo's CI security checks LOCALLY, at the SAME pinned versions.
# Goal: local == github. What passes here passes CI — no more "green locally, red on GitHub".
#
# AUTO-DETECTING: it reads `.github/workflows/ci.yml` and runs ONLY what that CI runs
# (shellcheck, actionlint, zizmor, semgrep, osv-scanner, gitleaks — depending on the markers present).
# So a SINGLE file serves the template AND every generated project (node/static/generic/Android/C++…).
# The ONLY deliberate addition: it also validates any `renovate.json` present — to catch the failure
# mode "broken Renovate config → silent freeze of updates", which a project's CI does not cover.
#
# Usage:  ./check.sh            everything
#         ./check.sh --commit   only what a commit can make say something new (see MODE below)
#         ./check.sh --house    ONLY the house checks — the gate a CI calls (see MODE below)
#
# Versions are NEVER hardcoded: read from `ci.yml` (+ `requirements-ci.txt`). Binaries are cached
# under `.ci-tools/` (gitignored). CI itself verifies the SHA256 of the Linux asset; here we pin the
# VERSION (same rules → same findings) and verify it via `--version`. The strong checksum stays CI's
# job, the authority. This script is a pre-flight, not the barrier.
set -euo pipefail
cd "$(dirname "$0")"

CI=.github/workflows/ci.yml
CACHE=.ci-tools
mkdir -p "$CACHE"
[ -f "$CI" ] || { echo "No $CI here — nothing to replay."; exit 0; }

# --commit: the lot a COMMIT can make say something new. Left out is everything whose verdict is
# fixed by an external base rather than by the tree — the OSV database and the semgrep packs are
# fetched, and gitleaks' rules are baked into a pinned binary, so at constant versions the pushed
# history returns the same answer it did an hour ago. Those stay with the full lot and the CI.
#
# The checks that DO read the tree read ALL of it, in both modes: a check narrowed to the diff is
# blind by construction — deleting a file breaks a link in another one, which no diff mentions.
# What `touched` decides is whether a check RUNS, never what it looks at.
#
# --house is the CI's door, and the reason it exists is that the alternative is a hand-kept list.
# A workflow naming its checks one step at a time has to be edited in every template the day a check
# is added, in every direction, silently — the failure this repository has already paid for. One
# line calls this mode, and whatever sits under checks/ runs behind it.
# It runs the house checks and NOTHING else: gitleaks, semgrep, osv-scanner, actionlint and zizmor
# are the CI's OWN steps, at versions it pins and checksums itself. Replaying them here would
# download and rerun the whole lot a second time, in the same job, for the same verdict.
MODE=full
case "${1:-}" in
  --commit) MODE=commit;;
  --house)  MODE=house;;
esac
changed=""
# The neighbouring workspace/ is a SEPARATE git repository, so a diff run here is blind to it —
# and two checks (verify-echo, verify-growth) read its prose. Without this, a SUIVI.md that
# doubles in size wakes nothing unless a .md happens to move here in the same commit.
[ "$MODE" = commit ] && changed=$( { git diff --name-only HEAD 2>/dev/null || true
                                     git -C ../workspace diff --name-only HEAD 2>/dev/null || true; } )
# Only --commit narrows anything: in every other mode a check runs, and what it READS is never
# narrowed in any of them.
touched() { [ "$MODE" != commit ] || printf '%s\n' "$changed" | grep -qE "$1"; }
# The external tools are the CI's own steps — skipped at the gate, run in the other two modes.
external() { [ "$MODE" != house ]; }

os=$(uname -s | tr '[:upper:]' '[:lower:]')          # darwin | linux
uarch=$(uname -m)
gl_arch=arm64; al_arch=arm64; osv_arch=arm64
[ "$uarch" = x86_64 ] && { gl_arch=x64; al_arch=amd64; osv_arch=amd64; }

fail=0
note() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; }
ko()   { printf '  \033[31m✗ %s\033[0m\n' "$1"; fail=1; }

# Replays one house check's captured output and returns its exit code. A missing capture is an
# ERROR, never a pass: a check that did not run must not read like a check that found nothing.
PAR="$CACHE/par"
reap() {
  [ -f "$PAR/$1.rc" ] || { echo "  (nothing captured for $1 — it never ran)"; return 1; }
  cat "$PAR/$1.out"; return "$(cat "$PAR/$1.rc")"
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
# Shared Python venv for zizmor and semgrep; only reinstalls if a version is missing.
#
# The installed version is read from disk: asking each tool booted a Python interpreter, 1.5 s per run.
# That no longer proves the tool STARTS, and one way to break it is known — moving the project
# directory leaves the venv's absolute shebangs pointing nowhere, `pip` included, so it cannot be
# repaired in place. The interpreter pip's shebang names is checked instead, and the venv rebuilt.
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
[ -n "$RENOVATE_PKG" ] || RENOVATE_PKG=renovate@43.288.0

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

# The house checks read the tree and write nothing, so they all start here, at once: their sum
# becomes their slowest, and it runs under the external tools instead of after them. Each output is
# captured and replayed further down by the block that owns it, so the report reads in the order it
# always did. `verify-travel.sh` stays out — it generates a whole project, and only runs when a
# travelling file moved; `verify-delegation.sh` too — it is a hook, and check.sh never calls it.
rm -rf "$PAR"; mkdir -p "$PAR"
for s in checks/verify-*.sh; do
  # The two hooks stay out: they read the event payload from STDIN, and inside this loop that means
  # competing for the terminal's stdin with every sibling started alongside them.
  case "$s" in *verify-travel.sh|*verify-delegation.sh|*verify-turn-claims.sh|*verify-forbidden-command.sh) continue;; esac
  # Second rhythm: each runs when ITS OWN target moved, and the two targets differ. verify-echo
  # reads prose only. verify-growth reads prose AND scripts — its second half compares a script's
  # comment growth against its code, so gating it on prose alone would blind it precisely on a
  # commit that touches nothing but scripts, which is when it has something to say.
  case "$s" in
    *verify-echo.sh)          touched '\.md$' || continue;;
    *verify-growth.sh)        touched '\.md$' || continue;;
    *verify-comment-drift.sh) touched '\.sh$' || continue;;
  esac
  [ -x "$s" ] || continue
  n=$(basename "$s" .sh)
  # `set +e` inside the subshell, and it is what makes the capture work at all: this file runs
  # under `set -e`, which the subshell inherits, so a check exiting non-zero killed it BEFORE the
  # .rc was written. A missing .rc then reads as "it never ran" — announced instead of the check's
  # own error message, which stayed in the .out and was never printed. Every failure looked alike,
  # and a real never-ran became indistinguishable from an ordinary red.
  ( set +e; "./$s" >"$PAR/$n.out" 2>&1; echo $? >"$PAR/$n.rc" ) &
done

if external && in_ci shellcheck && touched '\.sh$|^\.githooks/'; then
  note "shellcheck — shell scripts"
  targets=()
  while IFS= read -r f; do targets+=("$f"); done < <(
    find . -type f -name '*.sh' -not -path './.ci-tools/*' -not -path './.git/*' -not -path './node_modules/*')
  if [ -d .githooks ]; then while IFS= read -r f; do targets+=("$f"); done < <(find .githooks -type f); fi
  if [ "${#targets[@]}" -eq 0 ]; then ok "no shell scripts"
  elif ! command -v shellcheck >/dev/null 2>&1; then ko "shellcheck missing — 'brew install shellcheck'"
  elif shellcheck -S warning "${targets[@]}"; then ok "shellcheck"; else ko "shellcheck"; fi
fi

if external && in_ci actionlint && [ -d .github/workflows ] && touched '^\.github/workflows/'; then
  note "actionlint — workflows"
  if "$CACHE/actionlint" -color; then ok "actionlint"; else ko "actionlint"; fi
fi

# Its CONFIG counts as much as the workflows: tightening or loosening a rule in
# templates/repo/.github/zizmor.yml changes the verdict, and that path is not under
# .github/workflows/ — so gating on the workflows alone left the config unwatched.
if external && in_ci zizmor && [ -d .github/workflows ] && touched '^\.github/workflows/|zizmor\.yml$'; then
  note "zizmor — workflows (config $zconfig)"
  if "$CACHE/venv/bin/zizmor" --persona regular --config "$zconfig" .github/workflows/; then ok "zizmor"; else ko "zizmor"; fi
fi

if in_ci semgrep && [ "$MODE" = full ]; then
  note "semgrep — the code (curated packs)"
  if "$CACHE/venv/bin/semgrep" scan --error --quiet --metrics=off --exclude=.github \
       --config p/security-audit --config p/owasp-top-ten .; then ok "semgrep"; else ko "semgrep"; fi
fi

if in_ci osv-scanner && [ "$MODE" = full ]; then
  note "osv-scanner — dependencies (all manifests)"
  if "$CACHE/osv-scanner" scan source -r . --allow-no-lockfiles; then ok "osv"; else ko "osv"; fi
fi

# Scanning the whole history again at a constant binary version re-reads commits that already
# answered. What has NOT been pushed is the part that can still hold something new, and that scope
# costs the same on a repository of any size. It also sees a secret from a local commit whose file
# has since been deleted, which scanning the last commit alone misses.
if external && [ -n "$GITLEAKS_VERSION" ]; then
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ "$MODE" = commit ] && [ -n "$upstream" ]; then
    note "gitleaks — what is not on $upstream yet"
    if "$CACHE/gitleaks" git --no-banner --redact --log-opts="$upstream..HEAD"; then ok "gitleaks"; else ko "gitleaks"; fi
  else
    note "gitleaks — full history"
    if "$CACHE/gitleaks" git --no-banner --redact; then ok "gitleaks"; else ko "gitleaks"; fi
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

# verify-growth.sh — advisory: the curated docs must breathe, not only inflate. Compared against
# the last RELEASE, so the yardstick is the project's own history and not a number someone picked.
# Both of these follow the second rhythm, so a commit touching no prose skips them. That skip is
# announced as a SKIP: `reap` reports a missing capture as "it never ran", which is right when a
# check should have run and wrong here — and a skip that reads like a breakage is how a real
# breakage stops being noticed.
if [ -x checks/verify-echo.sh ]; then
  note "verify-echo.sh — the same fact stated twice, in different words (advisory)"
  if touched '\.md$'; then reap verify-echo || true
  else echo "  (skipped — no .md changed in this commit)"; fi
fi

if [ -x checks/verify-growth.sh ]; then
  note "verify-growth.sh — curated documents that only grow (advisory)"
  if touched '\.md$'; then reap verify-growth || true
  else echo "  (skipped — no .md changed in this commit)"; fi
fi

if [ -x checks/verify-comment-drift.sh ]; then
  note "verify-comment-drift.sh — a comment outgrowing its code (advisory)"
  if touched '\.sh$'; then reap verify-comment-drift || true
  else echo "  (skipped — no .sh changed in this commit)"; fi
fi

# verify-changelog.sh — two thirds of the CHANGELOG rule are PATHS, so two thirds are mechanical.
if [ -x checks/verify-changelog.sh ]; then
  note "verify-changelog.sh — a user-visible change with no CHANGELOG line"
  if reap verify-changelog; then ok "changelog"; else ko "changelog"; fi
fi

# verify-links.sh — a dead relative link is invisible: nothing renders an error, the reader just
# lands nowhere. This repo runs on pointers, so a broken one turns "one source" back into none.
if [ -x checks/verify-links.sh ]; then
  note "verify-links.sh — dead relative links (both repos)"
  if reap verify-links; then ok "links"; else ko "links"; fi
fi

# verify-workspace.sh — the neighbouring workspace/ has NO remote on purpose, which is exactly what
# makes it invisible: no diff-vs-origin, no CI, and this script runs in repo/ without looking beside it.
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

# verify-travel.sh — same shape. It GENERATES a throwaway project (~1s) to read the paths from
# where the files actually land: a grep of this tree cannot see a path that dies on landing.
if [ -x checks/verify-travel.sh ] && touched '^templates/|^checks/|^check\.sh$|^init-project\.sh$'; then
  note "verify-travel.sh — paths that die where the file lands"
  if ./checks/verify-travel.sh; then ok "travelling paths"; else ko "travelling paths"; fi
fi

# verify-version.sh — same shape: present only in this repo, silent no-op in a generated project.
if [ -x checks/verify-version.sh ]; then
  note "verify-version.sh — version coherence"
  if reap verify-version; then ok "version"; else ko "version"; fi
fi

# renovate-config-validator — whenever a renovate.json exists (beyond a project's CI: anti silent-freeze).
renovate_files=()
while IFS= read -r f; do renovate_files+=("$f"); done < <(
  find . -type f -name 'renovate.json' -not -path './.ci-tools/*' -not -path './.git/*' -not -path './node_modules/*')
# The pinned renovate version is read from ci.yml, and a bump can flip a valid config to
# invalid or back — so the workflow carrying the pin wakes the validator too.
if external && [ "${#renovate_files[@]}" -gt 0 ] && touched 'renovate\.json$|^\.github/workflows/ci\.yml$'; then
  note "renovate-config-validator — ${#renovate_files[@]} config(s)"
  # ONE npx call for all configs: npx reloads the renovate package on every invocation, and the
  # validator takes a file list and still names each file it rejects.
  if npx --yes --package "$RENOVATE_PKG" renovate-config-validator "${renovate_files[@]}" >/dev/null 2>&1
  then ok "renovate configs valid"; else ko "renovate config invalid"; fi
fi

# verify-tone.sh — same shared-script model: the rule lives THERE, the CI calls the same file.
# Copied into generated projects, where the rule applies just as much.
if [ -x checks/verify-tone.sh ]; then
  note "verify-tone.sh — second person (standard §1)"
  if reap verify-tone; then ok "no second person"; else ko "second person in versioned content"; fi
fi

echo
if [ "$fail" = 0 ]; then
  printf '\033[32m✓ local == github: all pass.\033[0m\n'
else
  printf '\033[31m✗ gaps above — CI will block on push.\033[0m\n'; exit 1
fi
