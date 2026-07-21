#!/usr/bin/env bash
# Rejoue LOCALEMENT les mêmes checks que `.github/workflows/ci.yml`, aux MÊMES versions épinglées.
# But : local == github. Ce qui passe ici passe la CI — plus de « vert en local, rouge sur GitHub ».
#
# Les versions ne sont JAMAIS écrites en dur ici : elles sont LUES depuis `ci.yml` et
# `templates/repo/requirements-ci.txt` — source unique, tenue à jour par Renovate.
#
# Les binaires épinglés sont mis en cache sous `.ci-tools/` (gitignoré). La CI, elle, vérifie le
# SHA256 de l'asset LINUX ; une machine de dev peut être macOS, donc ici on épingle la VERSION
# (mêmes règles → mêmes findings) et on la vérifie via `--version`. Le checksum fort reste le rôle
# de la CI, l'autorité. Ce script est un pré-vol, pas la barrière.
set -euo pipefail
cd "$(dirname "$0")"

CI=.github/workflows/ci.yml
CACHE=.ci-tools
mkdir -p "$CACHE"

os=$(uname -s | tr '[:upper:]' '[:lower:]')       # darwin | linux
uarch=$(uname -m)                                  # arm64 | x86_64
gl_arch=arm64; al_arch=arm64
[ "$uarch" = x86_64 ] && { gl_arch=x64; al_arch=amd64; }

fail=0
note() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; }
ko()   { printf '  \033[31m✗ %s\033[0m\n' "$1"; fail=1; }

# Lit un pin `NAME: valeur` dans ci.yml (le premier trouvé).
pin() { grep -m1 "^[[:space:]]*$1:" "$CI" | awk '{print $2}'; }

GITLEAKS_VERSION=$(pin GITLEAKS_VERSION)
ACTIONLINT_VERSION=$(pin ACTIONLINT_VERSION)
ZIZMOR_SPEC=$(grep -m1 '^zizmor==' templates/repo/requirements-ci.txt)
# Le major Renovate que valide la CI (`--package renovate@NN`).
RENOVATE_PKG=$(grep -m1 -o 'renovate@[0-9]*' "$CI" | head -1)

# --- gitleaks (tar.gz, binaire `gitleaks`) ---
ensure_gitleaks() {
  local bin="$CACHE/gitleaks" v="${GITLEAKS_VERSION#v}"
  if [ -x "$bin" ] && "$bin" version 2>/dev/null | grep -q "$v"; then return; fi
  local f="gitleaks_${v}_${os}_${gl_arch}.tar.gz"
  curl -sSfL -o "$CACHE/$f" \
    "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/${f}"
  tar -xzf "$CACHE/$f" -C "$CACHE" gitleaks
  rm -f "$CACHE/$f"
}

# --- actionlint (tar.gz, binaire `actionlint`) ---
ensure_actionlint() {
  local bin="$CACHE/actionlint" v="${ACTIONLINT_VERSION#v}"
  if [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -q "$v"; then return; fi
  local f="actionlint_${v}_${os}_${al_arch}.tar.gz"
  curl -sSfL -o "$CACHE/$f" \
    "https://github.com/rhysd/actionlint/releases/download/${ACTIONLINT_VERSION}/${f}"
  tar -xzf "$CACHE/$f" -C "$CACHE" actionlint
  rm -f "$CACHE/$f"
}

# --- zizmor (venv Python, version de requirements-ci.txt) ---
ensure_zizmor() {
  local venv="$CACHE/venv"
  if [ -x "$venv/bin/zizmor" ] && "$venv/bin/zizmor" --version 2>/dev/null | grep -q "${ZIZMOR_SPEC#zizmor==}"; then return; fi
  python3 -m venv "$venv"
  "$venv/bin/pip" install --quiet --upgrade pip >/dev/null
  "$venv/bin/pip" install --quiet "$ZIZMOR_SPEC"
}

note "Préparation des outils épinglés (${GITLEAKS_VERSION} · ${ACTIONLINT_VERSION} · ${ZIZMOR_SPEC} · ${RENOVATE_PKG})"
ensure_gitleaks
ensure_actionlint
ensure_zizmor
ok "outils prêts sous $CACHE/"

note "shellcheck — les scripts (comme le job lint-scripts)"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning init-project.sh configure-repo.sh check.sh; then ok "shellcheck"; else ko "shellcheck"; fi
else
  ko "shellcheck absent — 'brew install shellcheck' (la CI l'a préinstallé)"
fi

note "actionlint — les workflows"
if "$CACHE/actionlint" -color; then ok "actionlint"; else ko "actionlint"; fi

note "zizmor — les workflows (config livrée du template)"
if "$CACHE/venv/bin/zizmor" --persona regular --config templates/repo/.github/zizmor.yml .github/workflows/; then
  ok "zizmor"; else ko "zizmor"; fi

note "gitleaks — l'historique complet"
if "$CACHE/gitleaks" git --no-banner --redact; then ok "gitleaks"; else ko "gitleaks"; fi

note "renovate-config-validator — les 2 configs"
rv_ok=1
for f in .github/renovate.json templates/repo/.github/renovate.json; do
  npx --yes --package "$RENOVATE_PKG" renovate-config-validator "$f" >/dev/null 2>&1 || rv_ok=0
done
[ "$rv_ok" = 1 ] && ok "renovate configs" || ko "renovate config invalide"

echo
if [ "$fail" = 0 ]; then
  printf '\033[32m✓ local == github : tout passe.\033[0m\n'
else
  printf '\033[31m✗ échecs ci-dessus — à corriger avant de pousser.\033[0m\n'; exit 1
fi
