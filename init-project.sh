#!/usr/bin/env bash
set -euo pipefail

# Initialise un projet Claude Code selon le standard d'organisation.
#
# Usage : ./init-project.sh <projet> [owner/repo] [dossier-parent]
#              [--type static|node|generic] [--pages] [--artefact] [--staging] [--no-…]
#
#   <projet>          nom du projet (dossier créé)
#   [owner/repo]      si fourni, configure le remote GitHub en URL nue
#   [dossier-parent]  défaut : ~/Documents/Claude
#
#   --no-lifecycle-docs  N'écrit PAS `SUIVI.md`.
#
# Le script ne crée PAS le PAT (à faire sur github.com) ni ne push.

PROJ=""; SLUG=""; BASE="$HOME/Documents/Claude"; TYPE="static"
PAGES=""; ARTEFACT=""; STAGING=""      # vide = « non dit » → le raccourci décidera
LIFECYCLE_DOCS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --type)        TYPE="${2:?--type nécessite une valeur: static|node}"; shift 2;;
    --type=*)      TYPE="${1#*=}"; shift;;
    --pages)       PAGES=1;    shift;;
    --no-pages)    PAGES=0;    shift;;
    --artefact)    ARTEFACT=1; shift;;
    --no-artefact) ARTEFACT=0; shift;;
    --staging)     STAGING=1;  shift;;
    --no-staging)  STAGING=0;  shift;;
    --no-lifecycle-docs) LIFECYCLE_DOCS=0; shift;;
    -*)            echo "✗ option inconnue: $1"; exit 1;;
    *)             if [ -z "$PROJ" ]; then PROJ="$1"; elif [ -z "$SLUG" ]; then SLUG="$1"; else BASE="$1"; fi; shift;;
  esac
done
[ -n "$PROJ" ] || { echo "Usage: init-project.sh <projet> [owner/repo] [dossier-parent] [--type static|node|generic] [--pages] [--artefact] [--staging]"; exit 1; }
case "$TYPE" in static|node|generic) ;; *) echo "✗ --type doit être 'static' (défaut), 'node' ou 'generic' — c'est la TOOLCHAIN, pas l'hébergement"; exit 1;; esac

# Raccourcis : ils ne remplissent QUE ce qui n'a pas été dit explicitement.
# generic = toolchain non pré-câblée (Android, C/C++, Rust, Go…) : contrôles-sécu seuls, aucune
# capacité imposée — l'utilisateur opte via --pages/--artefact/--staging selon les 3 questions.
case "$TYPE" in
  static)  [ -n "$PAGES" ] || PAGES=1; [ -n "$ARTEFACT" ] || ARTEFACT=0; [ -n "$STAGING" ] || STAGING=0;;
  node)    [ -n "$PAGES" ] || PAGES=0; [ -n "$ARTEFACT" ] || ARTEFACT=1; [ -n "$STAGING" ] || STAGING=1;;
  generic) [ -n "$PAGES" ] || PAGES=0; [ -n "$ARTEFACT" ] || ARTEFACT=0; [ -n "$STAGING" ] || STAGING=0;;
esac

if [ "$STAGING" = 1 ] && [ "$ARTEFACT" = 0 ] && [ "$PAGES" = 1 ]; then
  echo "✗ --staging sans --artefact, sur un site Pages : Pages EST la prod, il n'y a rien à valider."
  echo "  Une 'develop' sans host à valider est un rituel vide — elle dérive et le merge cesse."
  exit 1
fi
TPL="$(cd "$(dirname "$0")" && pwd)"

DEST="$BASE/$PROJ"
if [ -e "$DEST" ]; then echo "✗ $DEST existe déjà — abandon."; exit 1; fi

echo "→ Création de $DEST"
mkdir -p "$DEST/repo" "$DEST/workspace/docs" "$DEST/workspace/plans" "$DEST/workspace/notes"

# Modèles repo/
cp "$TPL/templates/repo/.gitignore"    "$DEST/repo/.gitignore"
cp "$TPL/templates/repo/.env.example"  "$DEST/repo/.env.example"
cp "$TPL/templates/repo/.envrc"        "$DEST/repo/.envrc"
cp "$TPL/templates/repo/CLAUDE.md"     "$DEST/repo/CLAUDE.md"
cp "$TPL/templates/repo/README.md"     "$DEST/repo/README.md"
cp "$TPL/templates/repo/.env.example"  "$DEST/repo/.env"        # à remplir (gitignoré)

# Hook pre-commit (gitleaks) — versionné pour être partagé ; activé plus bas via core.hooksPath.
cp -R "$TPL/templates/repo/.githooks"        "$DEST/repo/.githooks"
# chmod sur TOUS les hooks, jamais nommément sur l'un d'eux : git ignore SILENCIEUSEMENT un hook
# non exécutable. Un `chmod +x pre-commit` en dur aurait rendu muet tout hook ajouté ensuite —
# un contrôle absent qui ne se voit pas, exactement ce que ce template passe son temps à traquer.
chmod +x "$DEST/repo/.githooks/"*

# Runner local == github : le MÊME check.sh que le template, auto-détectant (il lit le ci.yml du
# projet et ne rejoue QUE ce que sa CI lance). Le hook pre-commit le relance throttlé (consultatif).
cp "$TPL/check.sh" "$DEST/repo/check.sh"
chmod +x "$DEST/repo/check.sh"

# Fichiers versionnés GitHub (community + .github)
cp -R "$TPL/templates/repo/.github"          "$DEST/repo/.github"
cp "$TPL/templates/repo/.gitattributes"      "$DEST/repo/.gitattributes"
# Outils Python de la CI. SANS ce fichier, la CI échoue : elle fait `pip install -r requirements-ci.txt`.
cp "$TPL/templates/repo/requirements-ci.txt" "$DEST/repo/requirements-ci.txt"
cp "$TPL/templates/repo/SECURITY.md"         "$DEST/repo/SECURITY.md"
cp "$TPL/templates/repo/CODE_OF_CONDUCT.md"  "$DEST/repo/CODE_OF_CONDUCT.md"
cp "$TPL/templates/repo/CONTRIBUTING.md"     "$DEST/repo/CONTRIBUTING.md"
cp "$TPL/templates/repo/CHANGELOG.md"        "$DEST/repo/CHANGELOG.md"
cp "$TPL/templates/repo/AGENTS.md"           "$DEST/repo/AGENTS.md"   # versionné : lu par TOUS les agents
cp -R "$TPL/templates/repo/docs"             "$DEST/repo/docs"        # docs/adr/ — décisions structurantes
# <year> ET <copyright holder> : les deux sont déterministes (l'année, l'owner du slug). N'en
# substituer qu'un laissait une LICENSE juridiquement bancale — « Copyright (c) 2026 <copyright holder> ».
HOLDER="${SLUG%%/*}"; HOLDER="${HOLDER:-$PROJ}"   # sans fallback, LICENSE partait avec un titulaire VIDE
sed -e "s/<year>/$(date +%Y)/" -e "s/<copyright holder>/$HOLDER/" \
  "$TPL/templates/repo/LICENSE" > "$DEST/repo/LICENSE"   # MIT par défaut — VALIDER la licence (cf. repo/CLAUDE.md)

FRAG="$DEST/repo/.branching.frag"

# Le bloc est COMPOSÉ, jamais figé : il est VERSIONNÉ et PUBLIÉ. Un texte en dur mentirait dès que
# les capacités sortent du cas nominal — « Pages serves it directly » sur un repo --no-pages, ou
# « Production runs a pinned image tag » sans artefact. Un CONTRIBUTING qui décrit un flux que le
# repo n'a pas est pire qu'un CONTRIBUTING absent : on le croit.
{
  echo "## Branching"
  echo
  if [ "$STAGING" = 0 ]; then
    echo "GitHub Flow: \`main\` is always deployable."
    echo
    echo "- Branch off \`main\`: \`feat/…\` or \`fix/…\`."
    echo "- Open the pull request against \`main\`. The CI must be green before it is merged."
    echo "- **There is no staging branch, on purpose**: there is no host to validate against here."
    echo "  A \`develop\` branch with nothing to stage is an empty ritual, and a long-lived branch"
    echo "  that no one needs drifts until the merge stops happening."
  else
    echo "Three stages, because there is a real host to validate against before production."
    echo
    echo "- \`feat/…\` — branch off \`develop\`."
    echo "- \`develop\` — staging. Merged here first, deployed to the staging host, validated there."
    echo "- \`main\` — production. \`develop\` reaches it through a pull request."
    echo
    echo "**Keep \`develop\` short-lived** — merge in days, not weeks. A staging branch that lingers"
    echo "drifts from \`main\`, and that is precisely how an environment branch turns into the"
    echo "anti-pattern it is often accused of being."
  fi
  # Ce qui suit dépend des CAPACITÉS, pas du flux : chaque ligne n'est écrite que si elle est VRAIE.
  if [ "$PAGES" = 1 ]; then
    echo
    echo "Merging into \`main\` deploys the site: GitHub Pages serves it directly."
  fi
  if [ "$ARTEFACT" = 1 ]; then
    echo
    echo "A \`v*\` tag publishes the image to ghcr. Whoever deploys it runs a **pinned tag**"
    echo "(\`X.Y.Z\`), never \`:latest\` and never a branch: what gets promoted is the **artifact**,"
    echo "not the branch. The tag is immutable (a ruleset enforces it), so a pinned deployment"
    echo "cannot silently change under the host."
  fi
} > "$FRAG"

for f in CONTRIBUTING.md AGENTS.md; do
  sed -e "/<!-- BRANCHING -->/r $FRAG" -e "/<!-- BRANCHING -->/d" "$DEST/repo/$f" > "$DEST/repo/$f.tmp"
  mv "$DEST/repo/$f.tmp" "$DEST/repo/$f"
done
rm -f "$FRAG"

# Substituer <owner>/<repo> APRÈS toutes les copies. Sans ça, tout nouveau repo hérite de liens
# MORTS : advisories + discussions (config.yml), signalement de faille (SECURITY.md), clone (README).
if [ -n "$SLUG" ]; then
  REPO_ONLY="${SLUG#*/}"
  for f in .github/ISSUE_TEMPLATE/config.yml SECURITY.md README.md CHANGELOG.md; do
    # <owner>/<repo> D'ABORD, sinon <repo> seul le mange et le slug se retrouve tronqué.
    sed -e "s|<owner>/<repo>|$SLUG|g" -e "s|<repo>|$REPO_ONLY|g" \
      "$DEST/repo/$f" > "$DEST/repo/$f.tmp" && mv "$DEST/repo/$f.tmp" "$DEST/repo/$f"
  done
else
  echo "  ⚠ pas d'owner/repo fourni — remplacer <owner>/<repo> à la main :"
  echo "    config.yml · SECURITY.md · README.md · CHANGELOG.md"
fi


# ⚠ PAS de `codeql.yml` : CodeQL est activé par `configure-repo.sh` via le DEFAULT SETUP natif —
#   il détecte les langages et les TIENT À JOUR tout seul.
WT="$TPL/templates/workflows"
cp "$WT/ci-$TYPE.yml" "$DEST/repo/.github/workflows/ci.yml"
if [ "$PAGES" = 1 ]; then cp "$WT/pages.yml" "$DEST/repo/.github/workflows/pages.yml"; fi
if [ "$ARTEFACT" = 1 ]; then
  cp "$WT/docker-publish.yml" "$DEST/repo/.github/workflows/docker-publish.yml"
  IMG="${SLUG##*/}"; IMG="${IMG:-$PROJ}"
  DP="$DEST/repo/.github/workflows/docker-publish.yml"
  sed "s|<image-name>|$IMG|g" "$DP" > "$DP.tmp" && mv "$DP.tmp" "$DP"
fi

# ⚠ LES FILETS TOURNENT ICI, APRÈS la copie ET la substitution des workflows.
# Filet 1/2 — placeholders que le SCRIPT doit substituer. En rester un = lien mort ou commande
# cassée livrée à l'utilisateur. Sans ce contrôle, chaque NOUVEAU placeholder rejoue le bug en silence.
LEFT=$(grep -rln '<owner>/<repo>\|<repo>\|<image-name>\|<!-- BRANCHING -->' "$DEST/repo" 2>/dev/null || true)
if [ -n "$LEFT" ]; then
  echo "  ⚠ BUG DU TEMPLATE — placeholders non substitués (le script aurait dû le faire) :"
  printf '     %s\n' $LEFT
fi

# Filet 2/2 — placeholders que l'HUMAIN doit remplir, dans des fichiers VERSIONNÉS donc PUBLIÉS.
#   Ceux-là, le script ne PEUT pas les deviner (`<contact>`, `<one line>`…) — il ne doit surtout pas
#   les inventer. Mais les taire est pire : un `SECURITY.md` publié disant « reach out to <contact> »
#   laisse un chercheur SANS moyen de signaler une faille. C'est le défaut n°3 (liens morts), à
#   l'identique. → on les LISTE, et le passage en public les exige remplis (standard §18).
#   README volontairement EXCLU : il est évident à remplir, et ses balises HTML (<picture>, <p …>)
#   sont des faux positifs qui noieraient le seul message qui compte — celui sur `<contact>`.
HUMAN=$(grep -rl '<[a-z][^>]*>' "$DEST/repo/SECURITY.md" "$DEST/repo/CODE_OF_CONDUCT.md" \
  "$DEST/repo/LICENSE" "$DEST/repo/AGENTS.md" \
  "$DEST/repo/.github/workflows/pages.yml" 2>/dev/null || true)
if [ -n "$HUMAN" ]; then
  echo "  ⚠ À REMPLIR À LA MAIN avant le passage en PUBLIC (fichiers versionnés, donc publiés) :"
  for f in $HUMAN; do
    echo "     ${f#$DEST/repo/} → $(grep -o '<[a-z][^>]*>' "$f" | sort -u | tr '\n' ' ')"
  done
  echo "     ⚠ '<contact>' dans SECURITY.md : sans lui, personne ne peut signaler une faille."
fi

# Pas de bloc Dependabot : Renovate (renovate.json) est le seul bot d'update et AUTO-DÉTECTE
# npm/docker/actions/pip depuis les manifestes — aucune liste d'écosystèmes à tenir par toolchain.
# (Bascule full-Renovate, 2026-07 — cf. workspace/CHANTIER-AUTODETECTION.md.)

# Modèles workspace/
cp "$TPL/templates/workspace/README.md"           "$DEST/workspace/README.md"
cp "$TPL/templates/workspace/secrets-template.md" "$DEST/workspace/secrets.md"

# Docs de vie — default dès le 1er commit (standard §16).
# Un SQUELETTE, pas un titre : un fichier vide n'est pas rempli, il est ignoré. Les rubriques
# ci-dessous sont exactement les questions que se pose quelqu'un — humain ou IA — qui rouvre le
# projet à 6 mois et ne se souvient de rien.
#
# Heredoc QUOTÉ ('EOF') : sans les quotes, le shell interprète les backticks comme une substitution
# de commande et VIDE tous les `chemins` du modèle. Le nom du projet est substitué après, par sed.
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
  echo "  ↳ SUIVI.md NON créé (--no-lifecycle-docs)."
  echo "    Le PRINCIPE reste (standard §16), quel que soit l'outil qui le porte :"
  echo "    un seul doc de reprise CONCIS qui RENVOIE au détail · ce qui reste, BREF · livré PURGÉ."
fi

# Git — workspace/
cp "$TPL/templates/workspace/.gitignore" "$DEST/workspace/.gitignore"
git -C "$DEST/workspace" init -q -b main
git -C "$DEST/workspace" add -A       # `-A` ici, contrairement à repo/ : le contenu du workspace est LIBRE,
                                      # une liste explicite serait périmée dès la première note ajoutée.
git -C "$DEST/workspace" commit -q -m "initial workspace"
# Filet : un secret entré dans un objet git y reste — même sans remote (le repo peut en gagner un).
# C'est le SEUL garde-fou du `add -A` ci-dessus : si le .gitignore devient inopérant, on s'arrête ici.
if git -C "$DEST/workspace" ls-files --error-unmatch secrets.md >/dev/null 2>&1; then
  echo "✗ BUG DU TEMPLATE — secrets.md a été COMMITTÉ dans workspace/ (.gitignore inopérant)."; exit 1
fi

# Git — repo/
cd "$DEST/repo"
git init -q -b main

git config --local credential."https://github.com".helper ""
git config --local --add credential."https://github.com".helper \
  '!f() { echo username=x-access-token; echo "password=${GITHUB_PAT}"; }; f'
[ -n "$SLUG" ] && git remote add origin "https://github.com/$SLUG.git"   # URL nue, pas de PAT

# direnv — le PAT vit dans .envrc (JAMAIS dans .env : cf. standard §5).
# NB : éditer .envrc pour y coller le PAT invalidera cette autorisation → `direnv allow` à refaire.
if command -v direnv >/dev/null 2>&1; then direnv allow .; else echo "  (direnv absent — 'brew install direnv' puis 'direnv allow')"; fi

# Premier commit : uniquement les fichiers versionnés
# Liste EXPLICITE (jamais `git add -A` : `.env` et `.envrc` portent des secrets et sont gitignorés,
# mais on ne parie pas là-dessus). ⚠ Corollaire : tout fichier AJOUTÉ au template doit être ajouté
# ICI — sinon il est créé sur disque et JAMAIS committé. Le filet ci-dessous le rend bruyant.
git add .gitignore .env.example README.md .gitattributes LICENSE check.sh \
        SECURITY.md CODE_OF_CONDUCT.md CONTRIBUTING.md CHANGELOG.md AGENTS.md docs .github .githooks
# requirements-ci.txt est gitignoré EXPRÈS (soustrait au scan osv, cf. .gitignore) : un `git add` simple
# le sauterait EN SILENCE → CI cassée (`pip install -r`). `-f` le versionne quand même (motif .envrc).
git add -f requirements-ci.txt
git commit -q -m "initial project structure"

# Hook pre-commit gitleaks — ARMÉ APRÈS le commit initial (standard §18). Config LOCALE : un clone
# frais doit la reposer. ⚠ APRÈS, et pas avant : le commit initial est propre par CONSTRUCTION
# (liste EXPLICITE de fichiers, jamais .env/.envrc), donc rien à y scanner ; l'armer AVANT
# exigerait gitleaks pour committer ce scaffolding, et le hook HARD-FAIL en son absence bloquerait
# la génération elle-même — le script se sabordait après avoir prévenu « gitleaks absent ». Le hook
# protège les commits de DEV, pas le scaffolding.
git config --local core.hooksPath .githooks
command -v gitleaks >/dev/null 2>&1 || echo "  ⚠ gitleaks absent — 'brew install gitleaks' (sinon tout commit sera bloqué)"

# Filet : un fichier versionnable présent sur disque mais ABSENT du commit est un piège silencieux
# — la CI échouera au premier push sur un fichier « manquant » qu'on voit pourtant en local.
UNTRACKED=$(git ls-files --others --exclude-standard | grep -v '^\.env$\|^\.envrc$\|^\.branching\.frag$' || true)
if [ -n "$UNTRACKED" ]; then
  echo "  ⚠ NON COMMITÉ alors que versionnable — à ajouter au 'git add' de init-project.sh :"
  printf '     %s\n' $UNTRACKED
fi

# Capacité STAGING : `develop` existe DÈS LE DÉPART (standard §12). Sans elle, personne ne la crée
# jamais, et `configure-repo.sh` — qui ne la protège que si elle existe — ne la verrait pas.
if [ "$STAGING" = 1 ]; then
  git branch develop
  echo "  ↳ branche 'develop' créée (staging — standard §12). La pousser : git push -u origin develop"
fi

R="${SLUG:-<owner>/<repo>}"
cat <<EOF

✓ Projet initialisé : $DEST
  toolchain: $TYPE · capacités: pages=$PAGES artefact=$ARTEFACT staging=$STAGING
  Local prêt : arborescence, modèles, git init, 1er commit, remote en URL nue, direnv.

  ── ROMAIN ────────────────────────────────────────────────────────────
   1. PAT COURANT — fine-grained, **90 jours**, restreint à $R, SANS Administration
      (permissions : standard §5). → le coller dans repo/.envrc (GITHUB_PAT)
      puis 'direnv allow' (l'édition du .envrc invalide l'autorisation).
   2. Reporter la date d'expiration dans workspace/secrets.md.
      (Ensuite, .envrc prévient tout seul 14 jours avant l'échéance.)

  ── CLAUDE (après le point 1) ─────────────────────────────────────────
   3. Remplir repo/.env (vars app), repo/CLAUDE.md ; adapter .github/workflows/
      ($([ "$TYPE" = node ] && echo 'ajouter package.json' || echo 'ajuster ci.yml')$([ "$ARTEFACT" = 1 ] && echo ' ; ajouter Dockerfile')$([ "$PAGES" = 1 ] && echo ' ; <web-dir> dans pages.yml')) ; LICENSE : titulaire.
      ⚠ VALIDER la licence (MIT par défaut — vérifier compat deps/vendored).
   4. git push -u origin main

  ── ROMAIN (config serveur — l'assistant n'a JAMAIS Administration) ───
   5. ./configure-repo.sh $R '' '<description en une ligne>' '<topic-a,topic-b>'
      → ruleset main, secret scanning, Dependabot, squash-only, immutable releases,
        description, topics, et l'ACTIVATION DE CODEQL (default setup).
      ⚠ La description et les topics EXIGENT Administration : l'assistant reçoit un 403.
        SEUL ce script peut les poser. Sans description, le community health plafonne
        à 85 % ; sans topic, le repo ne remonte dans AUCUNE recherche par sujet.
      Demande un PAT admin ÉPHÉMÈRE en saisie masquée — À RÉVOQUER dès la fin.
      Permissions : Administration:write + Pages:write + Code scanning:read + Actions:read.
      NB : sur un repo PRIVÉ en plan Free, rulesets/secret scanning/CodeQL sont
      indisponibles → à rejouer au passage en public (après gitleaks sur l'historique).
      C'est ce REJEU qui active CodeQL : il n'y a plus de codeql.yml qui se réveille seul.

  ── CLAUDE ────────────────────────────────────────────────────────────
   6. Vérifier en lecture : CI verte, ruleset actif, CodeQL, community health.
EOF
