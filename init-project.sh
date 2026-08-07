#!/usr/bin/env bash
set -euo pipefail

# Initialize a Claude Code project per the organization standard.
#   (detail: docs/code/init-project.md)

PROJ=""; SLUG=""; BASE="$HOME/Documents/Claude"; TYPE="static"
PAGES=""; ARTEFACT=""; STAGING=""      # empty = "unspecified" → the shortcut will decide
LIFECYCLE_DOCS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --type)        TYPE="${2:?--type requires a value: static|node|generic}"; shift 2;;
    --type=*)      TYPE="${1#*=}"; shift;;
    --pages)       PAGES=1;    shift;;
    --no-pages)    PAGES=0;    shift;;
    --artefact)    ARTEFACT=1; shift;;
    --no-artefact) ARTEFACT=0; shift;;
    --staging)     STAGING=1;  shift;;
    --no-staging)  STAGING=0;  shift;;
    --no-lifecycle-docs) LIFECYCLE_DOCS=0; shift;;
    --version)     echo "project-template $(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo unreleased)"; exit 0;;
    -*)            echo "✗ unknown option: $1"; exit 1;;
    *)             if [ -z "$PROJ" ]; then PROJ="$1"; elif [ -z "$SLUG" ]; then SLUG="$1"; else BASE="$1"; fi; shift;;
  esac
done
[ -n "$PROJ" ] || { echo "Usage: init-project.sh <project> [owner/repo] [parent-folder] [--type static|node|generic] [--pages] [--artefact] [--staging]"; exit 1; }
case "$TYPE" in static|node|generic) ;; *) echo "✗ --type must be 'static' (default), 'node' or 'generic' — this is the TOOLCHAIN, not the hosting"; exit 1;; esac

# Shortcuts: they fill in ONLY what wasn't said explicitly.
# generic = toolchain not pre-wired: security checks only, capabilities opted in explicitly.
case "$TYPE" in
  static)  [ -n "$PAGES" ] || PAGES=1; [ -n "$ARTEFACT" ] || ARTEFACT=0; [ -n "$STAGING" ] || STAGING=0;;
  node)    [ -n "$PAGES" ] || PAGES=0; [ -n "$ARTEFACT" ] || ARTEFACT=1; [ -n "$STAGING" ] || STAGING=1;;
  generic) [ -n "$PAGES" ] || PAGES=0; [ -n "$ARTEFACT" ] || ARTEFACT=0; [ -n "$STAGING" ] || STAGING=0;;
esac

if [ "$STAGING" = 1 ] && [ "$ARTEFACT" = 0 ] && [ "$PAGES" = 1 ]; then
  echo "✗ --staging without --artefact, on a Pages site: Pages IS production, there's nothing to validate."
  echo "  A 'develop' with no host to validate is an empty ritual — it drifts and the merge stops happening."
  exit 1
fi
TPL="$(cd "$(dirname "$0")" && pwd)"

DEST="$BASE/$PROJ"
if [ -e "$DEST" ]; then echo "✗ $DEST already exists — aborting."; exit 1; fi

echo "→ Creating $DEST"
mkdir -p "$DEST/repo" "$DEST/workspace/docs" "$DEST/workspace/plans" "$DEST/workspace/notes"

# repo/ templates
cp "$TPL/templates/repo/.gitignore"    "$DEST/repo/.gitignore"
cp "$TPL/templates/repo/.env.example"  "$DEST/repo/.env.example"
cp "$TPL/templates/repo/.envrc"        "$DEST/repo/.envrc"
cp "$TPL/templates/repo/CLAUDE.md"     "$DEST/repo/CLAUDE.md"
cp "$TPL/templates/repo/README.md"     "$DEST/repo/README.md"
cp "$TPL/templates/repo/.env.example"  "$DEST/repo/.env"        # to fill in (gitignored)

# pre-commit hook (gitleaks) — versioned, enabled below via core.hooksPath.
# 🔴 From the ROOT, like check.sh and checks/ — never templates/: a second copy drifts.
cp -R "$TPL/.githooks"                       "$DEST/repo/.githooks"
# chmod on ALL hooks, never one by name: git SILENTLY ignores a hook that is not executable.
chmod +x "$DEST/repo/.githooks/"*

# local == github: the SAME check.sh, auto-detecting. The pre-commit hook reruns it and blocks.
cp "$TPL/check.sh" "$DEST/repo/check.sh"
chmod +x "$DEST/repo/check.sh"

# open-pr.sh opens a PR AND verifies the CI actually started: a PR with 0 runs reads as a pass.
cp "$TPL/open-pr.sh" "$DEST/repo/open-pr.sh"
chmod +x "$DEST/repo/open-pr.sh"

# configure-repo.sh travels: a generated project changes status on its own (private → public), and
# that is the ONE gesture needing server config it cannot reach without this script. Its single link
# to the RUNBOOK is PINNED on the way out — the version a project was born from stays true about it
# forever, where `main` would silently start describing something the project never received.
cp "$TPL/configure-repo.sh" "$DEST/repo/configure-repo.sh"
chmod +x "$DEST/repo/configure-repo.sh"

# Under checks/, exactly where they live here — check.sh looks for them THERE.
#   (detail: docs/code/init-project.md)
mkdir -p "$DEST/repo/checks"
cp "$TPL/checks/"verify-*.sh "$DEST/repo/checks/"
chmod +x "$DEST/repo/checks/"verify-*.sh

# Their notes travel WITH them: a check pointing at docs/code/<name>.md that lands where the file
# is absent carries a dead pointer — verify-travel.sh reports it, and rightly.
# 🔴 `verify-*.md` ONLY, plus the charter they all link to: the generator's OWN notes describe
# the tool that builds, which the built project has no use for (detail: docs/code/init-project.md).
mkdir -p "$DEST/repo/docs/code"
cp "$TPL/docs/code/"verify-*.md "$DEST/repo/docs/code/" 2>/dev/null || true
cp "$TPL/docs/code/README.md"          "$DEST/repo/docs/code/README.md"
cp "$TPL/docs/code/configure-repo.md"  "$DEST/repo/docs/code/configure-repo.md"

# Versioned GitHub files (community + .github)
cp -R "$TPL/templates/repo/.github"          "$DEST/repo/.github"
cp "$TPL/templates/repo/.gitattributes"      "$DEST/repo/.gitattributes"
# CI's Python tools. WITHOUT this file, the CI fails: it runs `pip install -r requirements-ci.txt`.
cp "$TPL/templates/repo/requirements-ci.txt" "$DEST/repo/requirements-ci.txt"
cp "$TPL/templates/repo/SECURITY.md"         "$DEST/repo/SECURITY.md"
cp "$TPL/templates/repo/CODE_OF_CONDUCT.md"  "$DEST/repo/CODE_OF_CONDUCT.md"
cp "$TPL/templates/repo/CONTRIBUTING.md"     "$DEST/repo/CONTRIBUTING.md"
cp "$TPL/templates/repo/CHANGELOG.md"        "$DEST/repo/CHANGELOG.md"
cp "$TPL/templates/repo/AGENTS.md"           "$DEST/repo/AGENTS.md"   # versioned: read by ALL agents
# Trailing `/.`, and the two copy traps it avoids: docs/code/init-project.md.
cp -R "$TPL/templates/repo/docs/."           "$DEST/repo/docs/"       # docs/adr/ — structuring decisions
find "$DEST/repo" -name .DS_Store -delete 2>/dev/null || true   # cp -R reads the DISK, not git

# <year> AND <copyright holder>: substituting only one leaves a legally shaky LICENSE.
HOLDER="${SLUG%%/*}"; HOLDER="${HOLDER:-$PROJ}"   # without a fallback, LICENSE would ship with an EMPTY holder
for l in LICENSE LICENSE-MIT; do
  sed -e "s/<year>/$(date +%Y)/" -e "s/<copyright holder>/$HOLDER/" \
    "$TPL/templates/repo/$l" > "$DEST/repo/$l"   # PolyForm NC by default — VALIDATE the license (see repo/CLAUDE.md)
done

FRAG="$DEST/repo/.branching.frag"

# COMPOSED, never fixed: a hardcoded flow the repo does not have is worse than none — it gets believed.
{
  echo "## Branching"
  echo
  if [ "$STAGING" = 0 ]; then
    echo "GitHub Flow: \`main\` is always deployable."
    echo
    echo "- Branch off \`main\`: \`feat/…\` or \`fix/…\`."
    echo "- Open the pull request against \`main\`. The CI must be green before it is merged."
    echo "- **There is no staging branch, on purpose**: there is no host to validate against here."
    echo "  A \`develop\` branch with nothing to stage is an empty ritual, and a long-lived branch that no one needs drifts until the merge stops happening."
  else
    echo "Three stages, because there is a real host to validate against before production."
    echo
    echo "- \`feat/…\` — branch off \`develop\`."
    echo "- \`develop\` — staging. Merged here first, deployed to the staging host, validated there."
    echo "- \`main\` — production. \`develop\` reaches it through a pull request."
    echo
    echo "**Keep \`develop\` short-lived** — merge in days, not weeks."
    echo "A staging branch that lingers drifts from \`main\`, and that is precisely how an environment branch turns into the anti-pattern it is often accused of being."
  fi
  # What follows depends on CAPABILITIES, not the flow: each line is written only if it's TRUE.
  if [ "$PAGES" = 1 ]; then
    echo
    echo "Merging into \`main\` deploys the site: GitHub Pages serves it directly."
  fi
  if [ "$ARTEFACT" = 1 ]; then
    echo
    echo "A \`v*\` tag publishes the image to ghcr."
    echo "Whoever deploys it runs a **pinned tag** (\`X.Y.Z\`), never \`:latest\` and never a branch: what gets promoted is the **artifact**, not the branch."
    echo "The tag is immutable (a ruleset enforces it), so a pinned deployment cannot silently change under the host."
  fi
} > "$FRAG"

# ONE file receives it: AGENTS.md is the authority and the file an agent reads; CONTRIBUTING.md
# points at it. Injecting into both is the trap (detail: docs/code/init-project.md).
sed -e "/<!-- BRANCHING -->/r $FRAG" -e "/<!-- BRANCHING -->/d" "$DEST/repo/AGENTS.md" > "$DEST/repo/AGENTS.md.tmp"
mv "$DEST/repo/AGENTS.md.tmp" "$DEST/repo/AGENTS.md"
rm -f "$FRAG"

# Stamp WHICH version built this project: a generated project carries a FROZEN COPY, and without
# this line nothing says whether a later fix ever reached it (detail: docs/code/init-project.md).
TPL_VERSION=$(git -C "$TPL" describe --tags --abbrev=0 2>/dev/null || echo unreleased)
# EXPLICIT flags, negatives included — a default that moves must not silently reproduce another
# project (detail: docs/code/init-project.md).
TPL_OPTS="--type $TYPE"
[ "$PAGES"    = 1 ] && TPL_OPTS="$TPL_OPTS --pages"    || TPL_OPTS="$TPL_OPTS --no-pages"
[ "$ARTEFACT" = 1 ] && TPL_OPTS="$TPL_OPTS --artefact" || TPL_OPTS="$TPL_OPTS --no-artefact"
[ "$STAGING"  = 1 ] && TPL_OPTS="$TPL_OPTS --staging"  || TPL_OPTS="$TPL_OPTS --no-staging"
[ "$LIFECYCLE_DOCS" = 0 ] && TPL_OPTS="$TPL_OPTS --no-lifecycle-docs"
sed -i.bak -e "s|<template-version>|$TPL_VERSION|g" \
           -e "s|<template-options>|$TPL_OPTS|g" \
           -e "s|<template-origin>|https://github.com/actarus314/project-template|g" \
  "$DEST/repo/AGENTS.md" && rm -f "$DEST/repo/AGENTS.md.bak"
# Same tag, same reason: the ONE link configure-repo.sh carries is pinned to it. Skipped when there
# is no tag — `blob/unreleased/` would 404, and a dead link is worse than a moving one.
if [ "$TPL_VERSION" != "unreleased" ]; then
  sed -i.bak "s|project-template/blob/main/|project-template/blob/$TPL_VERSION/|g" \
    "$DEST/repo/configure-repo.sh" && rm -f "$DEST/repo/configure-repo.sh.bak"
fi

# ⚠ The key is INJECTED HERE, never carried by the template.
#   (detail: docs/code/init-project.md)
if [ "$STAGING" = 1 ]; then
  RJ="$DEST/repo/.github/renovate.json"
  sed -e 's|^  "schedule":|  "baseBranchPatterns": ["develop"],\
\
  "schedule":|' "$RJ" > "$RJ.tmp" && mv "$RJ.tmp" "$RJ"
fi

# Substitute <owner>/<repo> AFTER all the copies. Without this, every new repo inherits
# DEAD links: advisories + discussions (config.yml), vulnerability reporting (SECURITY.md), clone (README).
if [ -n "$SLUG" ]; then
  REPO_ONLY="${SLUG#*/}"
  for f in .github/ISSUE_TEMPLATE/config.yml SECURITY.md README.md CHANGELOG.md; do
    # <owner>/<repo> FIRST, otherwise <repo> alone eats it and the slug ends up truncated.
    sed -e "s|<owner>/<repo>|$SLUG|g" -e "s|<repo>|$REPO_ONLY|g" \
      "$DEST/repo/$f" > "$DEST/repo/$f.tmp" && mv "$DEST/repo/$f.tmp" "$DEST/repo/$f"
  done
else
  echo "  ⚠ no owner/repo given — replace <owner>/<repo> by hand:"
  echo "    config.yml · SECURITY.md · README.md · CHANGELOG.md"
fi


# ⚠ NO `codeql.yml`: CodeQL is enabled by `configure-repo.sh` via the native DEFAULT SETUP —
#   it detects the languages and KEEPS THEM UP TO DATE on its own.
WT="$TPL/templates/workflows"
cp "$WT/ci-$TYPE.yml" "$DEST/repo/.github/workflows/ci.yml"
if [ "$PAGES" = 1 ]; then cp "$WT/pages.yml" "$DEST/repo/.github/workflows/pages.yml"; fi
if [ "$ARTEFACT" = 1 ]; then
  cp "$WT/docker-publish.yml" "$DEST/repo/.github/workflows/docker-publish.yml"
  # ghcr rejects an uppercase image reference; why lowercasing it here, at the source, and not
  # only in metadata-action: docs/code/init-project.md.
  IMG="$(printf '%s' "${SLUG##*/}" | tr '[:upper:]' '[:lower:]')"; IMG="${IMG:-$PROJ}"
  DP="$DEST/repo/.github/workflows/docker-publish.yml"
  # This file needs its OWN <owner>/<repo> substitution, copied as it is after the global pass:
  # docs/code/init-project.md.
  sed -e "s|<image-name>|$IMG|g" ${SLUG:+-e "s|<owner>/<repo>|$SLUG|g"} "$DP" > "$DP.tmp" && mv "$DP.tmp" "$DP"
  # One home for the release job, never two racing on the same tag: docs/code/init-project.md.
  rm -f "$DEST/repo/.github/workflows/release.yml"
fi

# ⚠ THE SAFETY NETS RUN HERE, AFTER the copy AND the workflow substitution.
# Net 1/2 — placeholders the SCRIPT must substitute. One left behind = a dead link or broken
# command shipped to the user. Without this check, every NEW placeholder replays the bug silently.
# Skips what is copied verbatim from the root: never substituted, and it DOCUMENTS these markers.
LEFT=$(grep -rln '<owner>/<repo>\|<repo>\|<image-name>\|<template-version>\|<!-- BRANCHING -->' "$DEST/repo" 2>/dev/null \
       | grep -vE '/(check|open-pr|configure-repo)\.sh$|/checks/|/docs/(code|server-config\.md)' || true)
if [ -n "$LEFT" ]; then
  echo "  ⚠ TEMPLATE BUG — unsubstituted placeholders (the script should have done it):"
  printf '     %s\n' $LEFT
fi

# Net 2/2 — placeholders the HUMAN must fill in, in VERSIONED files, so PUBLISHED.
#   (detail: docs/code/init-project.md)
HUMAN=$(grep -rl '<[a-z][^>]*>' "$DEST/repo/SECURITY.md" "$DEST/repo/CODE_OF_CONDUCT.md" \
  "$DEST/repo/AGENTS.md" \
  "$DEST/repo/.github/workflows/pages.yml" 2>/dev/null || true)
if [ -n "$HUMAN" ]; then
  echo "  ⚠ TO FILL IN BY HAND before going PUBLIC (versioned files, so published):"
  for f in $HUMAN; do
    echo "     ${f#$DEST/repo/} → $(grep -o '<[a-z][^>]*>' "$f" | sort -u | tr '\n' ' ')"
  done
  echo "     ⚠ '<contact>' in SECURITY.md: without it, no one can report a vulnerability."
fi

# No dependabot.yml on purpose: docs/security-and-updates.md owns which bot updates what, and why.

# workspace/ templates
cp "$TPL/templates/workspace/README.md"           "$DEST/workspace/README.md"
cp "$TPL/templates/workspace/secrets-template.md" "$DEST/workspace/secrets.md"
# The list verify-private-names.sh reads. It ships EMPTY and commented: the check travels with the
# repo, so its list has to exist beside it, or the pointer in its note lands nowhere.
cp "$TPL/templates/workspace/private-names.txt"   "$DEST/workspace/private-names.txt"

# Lifecycle docs — default from the 1st commit (docs/METHODE.md).
#   (detail: docs/code/init-project.md)
if [ "$LIFECYCLE_DOCS" = 1 ]; then

cat > "$DEST/workspace/docs/SUIVI.md" <<'EOF'
# Suivi — __PROJ__

> **Le doc CHAUD — reprise à froid.** À lire en premier après un `/clear` ou 6 mois d'absence.
> **RESTER COURT** : lu et édité très souvent, il **RENVOIE** au détail, il ne l'absorbe pas.
> **Le SUIVI respire** : il grossit pendant une étape, puis **rétrécit à sa clôture** — on élague ici, et on écrit une **synthèse** (quoi/comment/pourquoi, jamais un dump) dans **`archives/`** (un dossier par étape close, froid et immuable).
> Détail par ailleurs : `../repo/docs/adr/` (décisions) · `../plans/` (planification) · `../notes/`. Stable & cadrant → `repo/AGENTS.md` ; mouvant → ici.

## État actuel
<Où en est le projet, en 3 lignes. Version en prod, ce qui tourne, ce qui est en chantier.>

## Environnements
| Env | Host | Suit | URL |
|---|---|---|---|
| prod | <NUC / Pages> | <tag épinglé vX.Y.Z> | <url> |

## Historique (le plus récent en haut)
- YYYY-MM-DD — <ce qui a été livré, et pourquoi>

## Décisions
Les décisions **structurantes** vivent dans `../repo/docs/adr/` (versionnées, immuables).
Ici : seulement les décisions **de projet** (priorités, arbitrages, renoncements).

## Pièges connus / cicatrices
<Ce qui a déjà cassé une fois, et qu'on ne veut pas revivre.>

## Ce qui reste
> **Bref.** La prochaine chose à faire ; le livré est **PURGÉ** (il remonte dans l'Historique). Un chantier lourd → un **plan** dans `../plans/`, et on POINTE ici.
- [ ] <la prochaine chose>

## Notes ouvertes / questions
- <ce qui n'est pas tranché, et attend une décision>
EOF

sed "s/__PROJ__/$PROJ/" "$DEST/workspace/docs/SUIVI.md" > "$DEST/workspace/docs/SUIVI.tmp"
mv "$DEST/workspace/docs/SUIVI.tmp" "$DEST/workspace/docs/SUIVI.md"

else
  echo "  ↳ SUIVI.md NOT created (--no-lifecycle-docs)."
  echo "    The PRINCIPLE still stands (docs/METHODE.md), whatever tool carries it:"
  echo "    a single CONCISE recap doc that POINTS to the detail · what's left, BRIEF · delivered PURGED."
fi

# Git — workspace/
cp "$TPL/templates/workspace/.gitignore" "$DEST/workspace/.gitignore"
git -C "$DEST/workspace" init -q -b main
git -C "$DEST/workspace" add -A       # `-A` here, unlike repo/: workspace content is FREE-FORM,
                                      # an explicit list would go stale the moment the first note is added.
git -C "$DEST/workspace" commit -q -m "initial workspace"
# Net: a secret entered into a git object stays there — even without a remote (the repo can gain one later).
# This is the ONLY safety net for the `add -A` above: if .gitignore stops working, this is where it stops.
if git -C "$DEST/workspace" ls-files --error-unmatch secrets.md >/dev/null 2>&1; then
  echo "✗ TEMPLATE BUG — secrets.md was COMMITTED into workspace/ (.gitignore not working)."; exit 1
fi

# Git — repo/
cd "$DEST/repo"
git init -q -b main

git config --local credential."https://github.com".helper ""
git config --local --add credential."https://github.com".helper \
  '!f() { echo username=x-access-token; echo "password=${GITHUB_PAT}"; }; f'
[ -n "$SLUG" ] && git remote add origin "https://github.com/$SLUG.git"   # bare URL, no PAT

# direnv — the PAT lives in .envrc (NEVER in .env: see docs/secrets-and-auth.md).
# NB: editing .envrc to paste in the PAT will invalidate this authorization → `direnv allow` must be redone.
if command -v direnv >/dev/null 2>&1; then direnv allow .; else echo "  (direnv missing — 'brew install direnv' then 'direnv allow')"; fi

# First commit: only the versioned files
# EXPLICIT list (never `git add -A`: `.env` and `.envrc` carry secrets and are gitignored,
# but that's not something to bet on). ⚠ Corollary: every file ADDED to the template must be added
# HERE — otherwise it's created on disk and NEVER committed. The net below makes that loud.
git add .gitignore .env.example README.md .gitattributes LICENSE LICENSE-MIT check.sh open-pr.sh configure-repo.sh \
        CLAUDE.md \
        checks \
        SECURITY.md CODE_OF_CONDUCT.md CONTRIBUTING.md CHANGELOG.md AGENTS.md docs .github .githooks
# requirements-ci.txt is gitignored ON PURPOSE (excluded from the osv scan, see .gitignore): a plain `git add`
# would skip it SILENTLY → broken CI (`pip install -r`). `-f` versions it anyway (same pattern as .envrc).
git add -f requirements-ci.txt
git commit -q -m "initial project structure"

# gitleaks pre-commit hook — ARMED AFTER the initial commit (docs/repo-controls.md). LOCAL config:
#   (detail: docs/code/init-project.md)
git config --local core.hooksPath .githooks
command -v gitleaks >/dev/null 2>&1 || echo "  ⚠ gitleaks missing — 'brew install gitleaks' (otherwise every commit will be blocked)"

# Net: a versionable file present on disk but ABSENT from the commit is a silent trap
# — the CI will fail on the first push over a "missing" file that's plainly visible locally.
UNTRACKED=$(git ls-files --others --exclude-standard | grep -v '^\.env$\|^\.envrc$' || true)
if [ -n "$UNTRACKED" ]; then
  echo "  ⚠ NOT COMMITTED although versionable — add it to init-project.sh's 'git add':"
  printf '     %s\n' $UNTRACKED
fi

# STAGING capability: `develop` exists FROM THE START (docs/repo-controls.md). Without it, no one ever
# creates it, and `configure-repo.sh` — which only protects it if it exists — would never see it.
if [ "$STAGING" = 1 ]; then
  git branch develop
  echo "  ↳ 'develop' branch created (staging — docs/repo-controls.md). Push it: git push -u origin develop"
fi

R="${SLUG:-<owner>/<repo>}"
cat <<EOF

✓ Project initialized: $DEST
  toolchain: $TYPE · capabilities: pages=$PAGES artefact=$ARTEFACT staging=$STAGING
  Local ready: tree, templates, git init, 1st commit, remote as a bare URL, direnv.

  ── MAINTAINER ────────────────────────────────────────────────────────
   1. CURRENT PAT — fine-grained, **90 days**, restricted to $R, WITHOUT Administration: write
      (permissions: docs/secrets-and-auth.md). → paste it into repo/.envrc (GITHUB_PAT)
      then 'direnv allow' (editing .envrc invalidates the authorization).
   2. Record the expiration date in workspace/secrets.md.
      (After that, .envrc warns on its own 14 days before the deadline.)

  ── CLAUDE (after step 1) ───────────────────────────────────────────
   3. Fill in repo/.env (app vars), repo/CLAUDE.md; adjust .github/workflows/
      ($([ "$TYPE" = node ] && echo 'add package.json' || echo 'adjust ci.yml')$([ "$ARTEFACT" = 1 ] && echo ' ; add Dockerfile')$([ "$PAGES" = 1 ] && echo ' ; <web-dir> in pages.yml')).
      ⚠ VALIDATE the license: PolyForm Noncommercial by default — it FORBIDS commercial use.
        Swap LICENSE for a permissive one if this project needs it. LICENSE-MIT stays either way:
        the files inherited from the template are MIT whatever this project chooses.
   4. git push -u origin main

  ── MAINTAINER (server config — the assistant NEVER has Administration: write) ───
   5. ./configure-repo.sh $R '' '<one-line description>' '<topic-a,topic-b>'
      → ruleset main, secret scanning, Dependabot, squash-only, immutable releases,
        description, topics, and CODEQL ACTIVATION (default setup).
      ⚠ The description and topics REQUIRE Administration: write — the assistant gets a 403.
        ONLY this script can set them. Without a description, community health caps
        at 85%; without a topic, the repo doesn't surface in ANY topic search.
      Asks for an EPHEMERAL admin PAT via masked input — REVOKE it as soon as done.
      Permissions: EXACT recipe in docs/RUNBOOK.md, step 7a
      (a missing permission fails SILENTLY).
      NB: on a PRIVATE repo on the Free plan, rulesets/secret scanning/CodeQL are
      unavailable → to be rerun when going public (after gitleaks on the history).
      It's this RERUN that activates CodeQL: there's no more codeql.yml waking up on its own.

  ── CLAUDE ────────────────────────────────────────────────────────────
   6. Verify by reading: CI green, ruleset active, CodeQL, community health.
EOF
