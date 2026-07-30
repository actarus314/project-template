#!/usr/bin/env bash
set -euo pipefail

# Configure les réglages SERVEUR d'un repo GitHub public selon le standard.
# One-shot, IDEMPOTENT (relançable sans créer de doublon).
#
# ⚠ Exécuté par ROMAIN — JAMAIS par l'assistant, qui n'a jamais Administration
#   (matrice PAT : cf. docs/github-repo-config.md §2).
#
# AUTH — PAT fine-grained ÉPHÉMÈRE, à créer puis RÉVOQUER dans la foulée :
#   RECETTE COMPLÈTE — une permission par endpoint appelé (vérifié sur la doc GitHub REST,
#   « Permissions required for fine-grained PATs ») :
#       · Administration: WRITE        → PATCH /repos · PUT /vulnerability-alerts · */rulesets
#                                        · PUT /immutable-releases  (même permission — rien à ajouter)
#       · Pages: WRITE                 → POST|PUT /pages   (création du site + source=workflow)
#       · Administration: WRITE (bis)  → PATCH /code-scanning/default-setup (ACTIVE CodeQL)
#                                        · PUT /topics
#       · Code scanning alerts: READ   → GET /code-scanning/analyses
#       · Actions: READ                → GET /actions/runs/{id} — SUIVRE le run de la 1re analyse
#                                        CodeQL. Sans lui, le script ne sait pas quand elle finit,
#                                        ne pose pas la regle `code_scanning`, et `main` reste NON
#                                        gardee. La boucle d'attente le DIT au lieu de patienter
#                                        six minutes dans le vide.
#       · Contents: READ               → GET /contents/... (détection de pages.yml)
#       · Metadata: READ               → implicite
#     ⚠ ADMINISTRATION NE SUFFIT PAS, et chaque permission manquante échoue en SILENCE :
#       tout le reste passe, et le contrôle absent ne se voit pas. Le script les rend BRUYANTES.
#   · « Only select repositories » = CE repo uniquement  → blast radius = 1 repo
#   · Créer/révoquer : https://github.com/settings/personal-access-tokens
#
#   Le token n'est stocké NULLE PART : ni keychain, ni .envrc, ni historique shell.
#   Le script le demande en SAISIE MASQUÉE (ou lit GH_TOKEN s'il est déjà exporté).
#   Rien à retirer ni à oublier ensuite : on révoque le token, on ne dégrade pas ses droits.
#
# Usage : ./configure-repo.sh <owner>/<repo> [homepage-url] [description] [topics-csv] [--dry-run]
#
# Ce que « Use this template » / init-project.sh NE font PAS (config serveur) :
# merge-methods, delete-branch, secret scanning, push protection, Dependabot,
# CodeQL, ruleset. C'est ce script qui les pose.
#
# --dry-run : LIT tout, n'ÉCRIT rien. Les diagnostics (visibilité, plan, CodeQL, community)
#   restent RÉELS — ce sont des GET, inoffensifs. Seules les MUTATIONS sont interceptées et
#   affichées. Sert à jouer le script sur un repo VIVANT sans rien risquer : c'est exactement
#   le cas de la mise en conformité des repos existants, où l'on ne peut pas se tromper.

DRY=0
# TABLEAU, et non une chaîne. Avec `ARGS="$ARGS $a"` puis `set -- $ARGS` (non quoté), le shell
# refaisait un word splitting sur les arguments déjà découpés : l'argument VIDE (`''` pour « pas de
# homepage ») DISPARAISSAIT — décalant tout d'un cran — et la description était COUPÉE à son premier
# mot.
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}   # `${ARGS[@]+…}` : reste sûr sous `set -u` quand le tableau est vide

SLUG="${1:?Usage: configure-repo.sh <owner>/<repo> [homepage-url] [description] [topics-csv] [--dry-run]}"
HOMEPAGE="${2:-}"
DESCRIPTION="${3:-}"
TOPICS="${4:-}"   # csv : « solana,bridge,web3 »

case "$HOMEPAGE" in
  ""|https://*|http://*) ;;
  *) echo "✗ homepage invalide : « $HOMEPAGE » — attendu une URL (https://…) ou une chaîne vide."
     echo "  Une homepage non-URL est publiée telle quelle sur la page du repo : un lien mort."
     echo "  Usage : ./configure-repo.sh <owner>/<repo> [homepage-url] [description] [topics-csv] [--dry-run]"
     exit 1 ;;
esac

# UN SEUL point d'interception pour TOUTES les écritures. Un garde par appel (il y en a 14)
# aurait garanti d'en oublier un — et un dry-run qui écrit une seule fois est pire qu'aucun,
# puisqu'on lui fait confiance.
#
# ⚠ FD 3 = copie du stdout d'ORIGINE. Indispensable : presque tous les appels sont suivis de
#   `>/dev/null 2>&1`, qui AVALERAIT le message du dry-run — le script afficherait ses « ✓ »
#   sans jamais montrer ce qu'il compte écrire. Un dry-run muet est pire qu'aucun dry-run.
exec 3>&1
mutate() {
  if [ "$DRY" -eq 1 ]; then
    printf '  [dry-run] ÉCRIRAIT : %s\n' "$*" >&3
    # DRAINER stdin, sinon le dry-run se SUICIDE. Deux appels sont PIPÉS (`… | jq | mutate gh api
    # --input -`) : sans lecture, jq écrit dans un pipe que personne n'ouvre → SIGPIPE, et
    # `set -e` + `pipefail` tuent le script À L'UPSERT DU RULESET — sans un mot (exit 141).
    # Tout ce qui suit était alors PERDU EN SILENCE : ruleset `tags` (donc le pin du §13), ruleset
    # `develop`, community health, et jusqu'au rappel de RÉVOQUER LE PAT ADMIN. Or c'est justement
    # sur un repo AYANT DÉJÀ un ruleset — la mise en conformité de l'existant — que le dry-run sert.
    # Le mode réel n'a jamais eu le bug : `gh api --input -` consomme stdin, lui.
    # `-p` et NON `-t` : il faut drainer LE PIPE, pas « tout ce qui n'est pas un terminal ». Avec
    # `[ -t 0 ]`, les 12 appels NON pipés lancés depuis un shell non interactif (CI, agent) auraient
    # attendu sur un `cat` qui ne rend jamais la main : un dry-run qui se fige au lieu de mentir.
    [ -p /dev/stdin ] && cat >/dev/null 2>&1
    return 0
  fi
  "$@"
}

# ═══ gh_val <jq-expr> <défaut> <args gh api…> — LIRE une valeur, ou rendre le DÉFAUT ═══════════
#
# 🔴 N'ÉCRIVEZ JAMAIS `x=$(gh api … || echo "défaut")`. C'EST CASSÉ, TOUJOURS.
#    `gh api` écrit le corps JSON de ses erreurs sur **STDOUT**, pas sur stderr. La substitution
#    capture donc CE JSON, *puis* y colle le `echo` :
#        x = '{"message":"Rate Limit Exceeded","status":"403"}défaut'
#    — une chaîne qui n'est égale à RIEN. Tous les tests qui suivent partent alors dans le mauvais
#    cas, EN SILENCE : `[ "$x" = "configured" ]` est faux, `[ "$x" -eq 0 ]` explose, `[ -n "$x" ]`
#    est VRAI alors que l'appel a ÉCHOUÉ.
#
#    La règle : `out=$(cmd)` GARDE la sortie même quand `cmd` échoue — mais l'AFFECTATION, elle,
#    hérite du code de retour. On teste donc CE code, et on JETTE la sortie. C'est tout le remède.
gh_val() {
  local expr="$1" fb="$2"; shift 2
  local out
  out=$(gh api "$@" --jq "$expr" 2>/dev/null) || { printf '%s' "$fb"; return 0; }
  [ -n "$out" ] || { printf '%s' "$fb"; return 0; }
  printf '%s' "$out"
}

if [ "$DRY" -eq 1 ]; then
  echo "══ MODE --dry-run : lecture seule. Aucune écriture. Les ✓ ci-dessous se lisent « aurait posé ». ══"
fi

command -v gh >/dev/null || { echo "✗ gh CLI requis"; exit 1; }
command -v jq >/dev/null || { echo "✗ jq requis"; exit 1; }

# PAT Administration ÉPHÉMÈRE — saisi À LA MAIN, jamais stocké (ni keychain, ni fichier).
# On IGNORE délibérément GH_TOKEN de l'ENVIRONNEMENT : le .envrc de tout repo l'exporte = PAT
# d'ÉCRITURE (sans Administration). ADMIN_PAT est la SEULE porte d'injection, EXPLICITE (tests/CI)
# — jamais un .envrc.
if [ -n "${ADMIN_PAT:-}" ]; then
  GH_TOKEN="$ADMIN_PAT"
else
  # ⚠ NE PAS recopier la recette ici. Cette ligne l'a listée, et la copie a DIVERGÉ en silence :
  #   il y manquait `Contents:read` (lire CONTRIBUTING.md) puis `Issues:read` (dater le Dependency
  #   Dashboard). Or c'est cette ligne-là qu'on lit en créant le token — une recette courte et fausse
  #   est pire qu'un renvoi, et chaque permission absente échoue EN SILENCE.
  printf 'PAT admin éphémère sur %s — recette EXACTE : docs/RUNBOOK.md, étape 7a\n' "$SLUG" >&2
  printf '  (une permission manquante ne lève AUCUNE erreur : le contrôle absent ne se voit pas)\n' >&2
  printf 'Saisie masquée : ' >&2
  GH_TOKEN=""                        # vider AVANT le read : un read sans tty laisserait le GH_TOKEN d'env (le PAT d'écriture)
  read -rs GH_TOKEN < /dev/tty || true
  printf '\n' >&2
fi
export GH_TOKEN
[ -n "${GH_TOKEN:-}" ] || { echo "✗ Aucun token fourni."; exit 1; }

echo "→ Configuration serveur de $SLUG"

# ⚠ Lire la visibilité AVANT tout diagnostic. Sans elle, le script accuse le PAT d'une permission
#   manquante là où c'est le PLAN qui bloque (privé/Free) — et envoie chercher un droit déjà là.
#   Elle est le SOCLE du diagnostic : illisible, on s'arrête — sinon chaque message en aval
#   accuse une mauvaise cause en silence. Mieux vaut un échec net qu'un rapport faux.
IS_PRIVATE=$(gh api "repos/$SLUG" --jq '.private' 2>/dev/null || true)
if [ "$IS_PRIVATE" != "true" ] && [ "$IS_PRIVATE" != "false" ]; then
  echo "✗ Visibilité de $SLUG illisible — le PAT ne voit pas le repo (slug faux, PAT expiré, ou hors scope)."
  echo "  Arrêt : sans elle, les diagnostics de ce script accuseraient la mauvaise cause."
  exit 1
fi

# 1. Merge : squash SEUL + suppression de branche au merge (historique cohérent). C'est AUSSI le
#    PRÉFLIGHT Administration : ce PATCH est la 1ère écriture et exige Administration:write. En réel,
#    un 403 ici = token sans Administration (mauvais token collé, ou « Read » au lieu de « Read and
#    write ») — on le DIT, au lieu du 403 brut de gh qui ne montre pas la cause.
if [ "$DRY" -eq 1 ]; then
  mutate gh repo edit "$SLUG" \
    --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false --delete-branch-on-merge
elif ! gh repo edit "$SLUG" \
    --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false --delete-branch-on-merge; then
  echo "✗ Le token fourni voit $SLUG mais n'a PAS Administration:write — écriture refusée."
  echo "  → soit ce n'est pas le PAT admin (le PAT d'écriture a pu être collé par erreur),"
  echo "    soit Administration est resté sur « Read » au lieu de « Read and write »."
  echo "  Recrée le PAT admin (RUNBOOK §1 étape 7a : Administration = Read and write) puis relance."
  exit 1
fi
[ -n "$HOMEPAGE" ] && mutate gh repo edit "$SLUG" --homepage "$HOMEPAGE"
# La description compte dans le community health (100 % inatteignable sans elle) et exige
# Administration : l'assistant reçoit un 403 — seul ce script peut la poser.
# L'API rejette en 422 tout caractère de contrôle (« description control characters are not
# allowed ») — un copier-coller depuis un terminal ou un doc en glisse facilement un, invisible.
# On les retire, et on signale ce qui a été retiré plutôt que de le faire en silence.
if [ -n "$DESCRIPTION" ]; then
  # RETIRER un caractère de contrôle laisse un TROU à sa place : « organisation,··public » — deux
  # espaces là où le caractère invisible se tenait. Le garde-fou évitait bien le 422, mais il
  # PUBLIAIT une description abîmée, et personne ne relisait ce qui était réellement posé.
  # → on nettoie, PUIS on recolle (`tr -s ' '` compresse les espaces), PUIS on RELIT à voix haute.
  # `tr ' '` et NON `tr -d` : SUPPRIMER un caractère de contrôle COLLE les mots qui l'entouraient —
  # une tabulation dans « A tool<TAB>for X » donnait « A toolfor X », publié tel quel. On le REMPLACE
  # par un espace, PUIS on compresse les espaces, PUIS on relit à voix haute ce qu'on pose.
  CLEAN=$(printf '%s' "$DESCRIPTION" | LC_ALL=C tr '\000-\037\177' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//')
  if [ "$CLEAN" != "$DESCRIPTION" ]; then
    echo "  ⚠ description nettoyée (caractères de contrôle / espaces en double — l'API refuse les premiers en 422) :"
    echo "    → « $CLEAN »"
  fi
  mutate gh repo edit "$SLUG" --description "$CLEAN"
fi
if [ -z "$DESCRIPTION" ] && [ -z "$(gh api "repos/$SLUG" --jq '.description // ""')" ]; then
  echo "  ⚠ aucune description sur le repo → community health plafonné à 85 %."
  echo "    La poser : ./configure-repo.sh $SLUG '' '<description>'"
fi
# Les topics EXIGENT Administration:write (`PUT /repos/{o}/{r}/topics` → `administration=write`)
# — donc l'assistant, qui n'a JAMAIS `Administration`, reçoit un 403 : SEUL ce script peut les poser.
# `--add-topic` AJOUTE, il n'écrase pas l'existant.
if [ -n "$TOPICS" ]; then
  mutate gh repo edit "$SLUG" --add-topic "$TOPICS"
elif [ "$(gh_val '.names | length' 0 "repos/$SLUG/topics")" -eq 0 ]; then
  echo "  ⚠ aucun topic sur le repo → il ne remonte dans AUCUNE recherche GitHub par sujet."
  echo "    Les poser : ./configure-repo.sh $SLUG '' '' 'topic-a,topic-b'"
fi
echo "  ✓ merge et delete-branch-on-merge (les DEUX revus plus bas selon 'develop')${HOMEPAGE:+, homepage}${DESCRIPTION:+, description}${TOPICS:+, topics}"

# Discussions — le gabarit `.github/ISSUE_TEMPLATE/config.yml` renvoie vers `/discussions` sur
# CHAQUE repo généré. Sans cette activation, ce lien est un 404 : le premier tiers qui cherche à
# poser une question tombe sur une page morte, et rien ne le signale au mainteneur. Le poser ici
# plutôt que dans le runbook — le script tient déjà le PAT admin que l'activation exige.
mutate gh api -X PATCH "repos/$SLUG" -F has_discussions=true >/dev/null 2>&1 \
  && echo "  ✓ Discussions ouvertes (sans elles, le lien 'Question / Discussion' du template d'issue est un 404)" \
  || echo "  ⚠ Discussions : échec — les ouvrir dans l'UI (Settings → General → Features), sinon le lien du template d'issue est mort"

# 2. Fonctionnalités de sécurité (ADMINISTRATION).
#    ⚠ Sur compte perso (non-org), certaines sous-clés peuvent être no-op —
#      confirmer ensuite dans Settings → Code security.
SS_OK=0
mutate gh api -X PATCH "repos/$SLUG" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' \
  >/dev/null 2>&1 || SS_OK=1
# 🔴 EN DRY-RUN, LE VERDICT NE PEUT PAS VENIR DU CODE DE RETOUR : `mutate` réussit TOUJOURS (il
#    n'appelle rien). Le ✓ s'afficherait donc même là où l'appel est VOUÉ à échouer — et sur un repo
#    privé Free, secret scanning est INDISPONIBLE. Or le dry-run est justement l'outil qui sert à
#    auditer un repo VIVANT sans rien risquer : le laisser annoncer « posé » produit un FAUX RAPPORT
#    DE CONFORMITÉ, exactement sur les repos privés qu'on audite. On tranche donc sur la VISIBILITÉ.
#    (Même garde que CodeQL plus bas — elle y avait été posée pour ce seul appel, jamais généralisée.)
if [ "$DRY" -eq 1 ]; then
  [ "$IS_PRIVATE" = "true" ] && SS_OK=1 || SS_OK=0
fi
if [ "$SS_OK" -eq 0 ]; then
  echo "  ✓ secret scanning + push protection"
else
  echo "  ⚠ secret scanning / push protection : NON activés."
  echo "    Attendu sur un repo PRIVÉ en plan Free (indisponibles — standard §18) :"
  echo "    le hook pre-commit gitleaks est alors le SEUL filet anti-secret."
  echo "    → REJOUER ce script au passage en public."
fi

# Flux à 3 étages ? Détecté DÈS ICI, et pas seulement au §12 qui l'utilise aussi : le §3a doit savoir
# s'il pose le filet Dependabot. Un PUT suivi d'un DELETE plus bas ne serait PAS neutre — activer les
# security updates RÉVEILLE le bot sur les alertes DÉJÀ ouvertes, et la PR part avant le DELETE.
#   DEUX sondes, car aucune ne suffit seule : la branche peut avoir été DÉTRUITE par la promotion
#   (cf. §12), et le repo publier malgré tout un flux à 3 étages. `CONTRIBUTING.md` est versionné, et
#   son bloc `## Branching` est composé par init-project.sh d'après la capacité STAGING : s'il annonce
#   3 étages, la branche DOIT exister — c'est le §12 qui traite l'écart.
HAS_DEVELOP=0
gh api "repos/$SLUG/branches/develop" >/dev/null 2>&1 && HAS_DEVELOP=1
WANTS_STAGING=0
gh api "repos/$SLUG/contents/CONTRIBUTING.md" --jq '.content' 2>/dev/null \
  | base64 -d 2>/dev/null | grep -q 'Three stages' && WANTS_STAGING=1

# 3. Dependabot alerts — la DÉTECTION de CVE (native, gratuite en privé). Gardée : Renovate la LIT
#    (vulnerabilityAlerts) pour ouvrir ses PR de remédiation. Sans elle, pas de PR sécu Renovate.
mutate gh api -X PUT "repos/$SLUG/vulnerability-alerts" >/dev/null 2>&1 \
  && echo "  ✓ Dependabot alerts (détection — Renovate les lit pour ses PR sécu)" \
  || echo "  ⚠ vulnerability-alerts : échec — vérifier dans l'UI"

# 3a. Dependabot security updates — le FILET, posé sur les flux à 2 étages SEULEMENT : à 3 étages ses
#     PR viseraient `main` et court-circuiteraient le staging (retrait plus bas pour l'état antérieur).
#     Le pourquoi, et la preuve de vie de Renovate qui conditionne le retrait : standard, « Qui met à
#     jour les dépendances ».
#     ⚠ ENDPOINT DÉDIÉ, et non une sous-clé de `security_and_analysis` : `dependabot_security_updates`
#       apparaît dans le schéma de RÉPONSE du GET /repos, mais PAS dans les body-params du PATCH.
#       Le passer au PATCH ne lève aucune erreur — il est simplement ignoré, EN SILENCE. Un réglage
#       qu'on croit posé parce que l'appel a répondu 200 est pire qu'un réglage absent.
#     Doit suivre `vulnerability-alerts` : les security updates n'ont rien à remédier sans la détection.
if [ "$HAS_DEVELOP" -eq 0 ] && [ "$WANTS_STAGING" -eq 0 ]; then
  mutate gh api -X PUT "repos/$SLUG/automated-security-fixes" >/dev/null 2>&1 \
    && echo "  ✓ Dependabot security updates (filet)" \
    || echo "  ⚠ automated-security-fixes : échec — vérifier Settings → Advanced Security."
fi

# 3b. Private vulnerability reporting — SANS LUI, LE LIEN DE SECURITY.md EST MORT.
#     SECURITY.md pointe vers /security/advisories/new : si la fonctionnalité est désactivée,
#     un chercheur externe n'a AUCUN moyen de signaler une faille en privé… et la publiera
#     donc en issue publique, avant tout correctif. Gratuit, aucun entretien.
#     PVR est **public-only** : c'est un gate de VISIBILITÉ, pas de plan. En dry-run le `✓`
#     ci-dessous serait donc annoncé à tort sur un repo privé — même garde qu'au §2.
PVR_OK=0
mutate gh api -X PUT "repos/$SLUG/private-vulnerability-reporting" >/dev/null 2>&1 || PVR_OK=1
# ⚠ `[ a ] && [ b ] && x=1` SEUL sur sa ligne renverrait 1 quand le test est faux — et `set -e`
#   tuerait le script. Le `if` n'est pas du style : c'est ce qui l'empêche de mourir en mode réel.
if [ "$DRY" -eq 1 ] && [ "$IS_PRIVATE" = "true" ]; then PVR_OK=1; fi
if [ "$PVR_OK" -eq 0 ]; then
  echo "  ✓ private vulnerability reporting (le lien de SECURITY.md fonctionne)"
elif [ "$IS_PRIVATE" = "true" ]; then
  echo "  ↳ private vulnerability reporting : SANS OBJET en privé (aucun chercheur externe n'y accède)."
  echo "    Sera posé au passage en public — c'est là qu'il devient indispensable."
else
  echo "  ⚠ private vulnerability reporting : ÉCHEC sur un repo PUBLIC → le lien de SECURITY.md est MORT."
  echo "    Un chercheur n'a alors aucun moyen de signaler en privé : il publiera la faille."
fi

# 3d. IMMUTABLE RELEASES — le pendant du ruleset 'tags' côté RELEASE (§13).
#     Le ruleset 'tags' fige le tag ; celui-ci fige les ASSETS de la release. Sans les deux,
#     le pin de prod `APP_IMAGE_TAG=1.2.3` reste contournable : on ne bouge pas le tag,
#     on remplace le binaire attaché sous le même tag.
#     🔴 NON RÉTROACTIF : « immutability will only apply to future releases ». C'est ce qui dicte
#       le moment : on le pose AU PLUS TÔT, sans attendre, car ce qui n'est pas couvert à la
#       publication d'une release ne le sera JAMAIS.
#     ⚠ POSÉ DÈS LE PRIVÉ — et surtout PAS gaté sur le public. Le réglage EST disponible sur un
#       repo privé Free : la case « Enable release immutability » y est présente et actionnable
#       (Settings → General → Releases), sans l'encart « Upgrade or make this repository public »
#       que GitHub affiche sur les features réellement gatées (Wikis, juste en dessous).
#       Le gater reviendrait à laisser DÉFINITIVEMENT nues les releases d'un repo qui ne bascule
#       jamais en public — et l'arbitrage est asymétrique : poser tôt ne coûte rien (idempotent),
#       poser trop tard ne se rattrape pas.
#     PUT sans corps → 204. GET renvoie { enabled, enforced_by_owner }.
if mutate gh api -X PUT "repos/$SLUG/immutable-releases" >/dev/null 2>&1; then
  echo "  ✓ immutable releases (les assets d'une release ne peuvent plus être remplacés)"
else
  echo "  ⚠ immutable releases : ÉCHEC → une release publiée pourra voir ses assets REMPLACÉS."
  echo "    Le pin du §13 devient contournable sans toucher au tag. Activer dans l'UI :"
  echo "    Settings → Releases → Enable release immutability (NON rétroactif : avant la v1)."
fi

# 3c. GITHUB_TOKEN en LECTURE SEULE par défaut (check OpenSSF « Token-Permissions »).
#     Nos workflows déclarent tous leur bloc `permissions:` — le gain n'est donc pas immédiat.
#     C'est un filet pour le workflow FUTUR qui oubliera de le faire : sans ce défaut, il hérite
#     d'un token en écriture. Gratuit, et le défaut n'est restrictif que pour les repos créés
#     après février 2023 — donc à poser explicitement pour ne rien supposer.
mutate gh api -X PUT "repos/$SLUG/actions/permissions/workflow" \
  -f 'default_workflow_permissions=read' \
  -F 'can_approve_pull_request_reviews=false' >/dev/null 2>&1 \
  && echo "  ✓ GITHUB_TOKEN par défaut = read (un workflow sans bloc 'permissions:' n'hérite plus d'un token en écriture)" \
  || echo "  ⚠ default_workflow_permissions : échec — vérifier Settings > Actions > General."

# 4. CodeQL : ACTIVÉ PAR CE SCRIPT, en DEFAULT SETUP (voir le bloc « ═══ CodeQL » plus bas).

# 5. GitHub Pages — CRÉER le site, source = GitHub Actions.
#    ⚠ Le `enablement: true` de actions/configure-pages NE SUFFIT PAS : créer un site Pages exige
#      Administration, que le GITHUB_TOKEN d'un workflow n'a pas → « Resource not accessible by
#      integration », à CHAQUE déploiement, tant que le site n'existe pas. C'est donc un geste
#      admin one-shot, sa place est ici.
#    Déclenché tout seul si le repo a un pages.yml : rien à mémoriser, aucun drapeau à passer.
# ⚠ Sur un repo PRIVÉ, GET /contents exige « Contents: read ». Sans elle, l'appel échoue et le
#   bloc Pages entier (homepage comprise) serait sauté EN SILENCE. On distingue donc les 3 cas :
#   workflow présent / absent / illisible. (Sur un repo public, l'API contents est ouverte.)
PAGES_WF=$(gh api "repos/$SLUG/contents/.github/workflows/pages.yml" --jq '.name' 2>/dev/null || true)
if [ -z "$PAGES_WF" ] && [ "$(gh api "repos/$SLUG" --jq '.private')" = "true" ]; then
  echo "  ↳ pages.yml non lisible — si ce repo en a un, le PAT admin manque « Contents: read »."
fi
if [ "$PAGES_WF" = "pages.yml" ]; then
  if gh api "repos/$SLUG/pages" >/dev/null 2>&1; then
    mutate gh api -X PUT "repos/$SLUG/pages" -f 'build_type=workflow' >/dev/null 2>&1 \
      && echo "  ✓ Pages : déjà créé, source confirmée = GitHub Actions" \
      || echo "  ⚠ Pages : site existant, source non modifiable — vérifier Settings → Pages"
  # 3ᵉ appel gaté par la VISIBILITÉ (après secret scanning et PVR) : Pages est indisponible sur un
  # repo privé Free. Même garde de dry-run — sans elle, `mutate` réussit et le script annonce un site
  # « créé » là où il ne peut pas exister. (La branche « déjà créé » ci-dessus n'en a PAS besoin :
  # que la LECTURE ait réussi prouve que ce repo peut porter des Pages.)
  else
    PAGES_OK=0
    mutate gh api -X POST "repos/$SLUG/pages" -f 'build_type=workflow' >/dev/null 2>&1 || PAGES_OK=1
    if [ "$DRY" -eq 1 ] && [ "$IS_PRIVATE" = "true" ]; then PAGES_OK=1; fi
    if [ "$PAGES_OK" -eq 0 ]; then
      echo "  ✓ Pages : site créé, source = GitHub Actions"
    # NE PAS imputer l'échec à la visibilité sans la lire : le vrai motif
    # était que le PAT admin n'avait pas « Pages: write » — permission DISTINCTE d'Administration.
    elif [ "$IS_PRIVATE" = "true" ]; then
      echo "  ⚠ Pages : indisponible sur un repo PRIVÉ en plan Free → sera créé au passage en public."
    else
      echo "  ⚠ Pages : création refusée sur un repo PUBLIC → le PAT admin manque « Pages: write »"
      echo "    (permission DISTINCTE d'Administration). L'ajouter et rejouer."
    fi
  fi

  # La homepage alimente l'item « documentation » du community profile : sans elle, le score
  # PUBLIC plafonne à 87 % (l'item n'existe pas sur un repo privé).
  # On la dérive du site Pages qu'on vient de créer : la boucle se ferme toute seule.
  if [ -z "$HOMEPAGE" ]; then
    PAGES_URL=$(gh api "repos/$SLUG/pages" --jq '.html_url' 2>/dev/null || true)
    case "$PAGES_URL" in
      https://*) mutate gh repo edit "$SLUG" --homepage "$PAGES_URL" >/dev/null 2>&1 \
                   && echo "  ✓ homepage = $PAGES_URL  (→ item « documentation » du community profile)" ;;
    esac
  fi
fi

# 6. Ruleset 'main' — idempotent : update si un ruleset du même nom existe, sinon create.
#    Minimal robuste : PR obligatoire (0 review, squash), no force-push/delete, CI requise.
#    ✅ REJOUABLE SANS DÉGÂT : les règles ajoutées à la main
#       (code_quality…) sont PRÉSERVÉES à la fusion. Auparavant, un PUT nu
#       remplaçait le ruleset entier et les effaçait en silence.
RULESET_NAME="main"

# CodeQL en check REQUIS (standard §17). Impossible sur un repo neuf — CodeQL n'a jamais tourné,
# l'exiger bloquerait TOUTE PR. On la pose donc dès que la 1ʳᵉ analyse existe, au lieu de la
# renvoyer à un geste manuel « à faire plus tard », c'est-à-dire jamais.
#
# ⚠ NE JAMAIS confondre « 0 analyse » et « je n'ai pas le droit de regarder ». Le PAT admin n'a
#   PAS « Code scanning alerts: read » par défaut : l'appel renvoie alors 403, et lire ça comme
#   « CodeQL n'a jamais tourné » fait SILENCIEUSEMENT sauter le contrôle.
# Checks REQUIS avant merge. `build-check` (capacité ARTEFACT) valide le Dockerfile ET scanne
# l'image (Trivy, CRITICAL/HIGH). S'il n'est pas EXIGÉ, le scan est DÉCORATIF : une PR portant une
# CVE critique passerait quand même. Détecté sur la présence du workflow — rien à mémoriser.
CHECKS_JSON='[ { "context": "checks" } ]'
if gh api "repos/$SLUG/contents/.github/workflows/docker-publish.yml" >/dev/null 2>&1; then
  CHECKS_JSON='[ { "context": "checks" }, { "context": "build-check" } ]'
  echo "  ↳ capacité ARTEFACT détectée (docker-publish.yml) → 'build-check' (Dockerfile + scan Trivy) devient un check REQUIS."
fi

# ═══ CodeQL : le DEFAULT SETUP natif, et NON PLUS un `codeql.yml` committé ═══════════════════
# Le default setup DÉTECTE les langages et SE MET À JOUR TOUT SEUL quand le repo change, scans
# programmés inclus. Le POURQUOI, les sources et le cas où l'advanced setup se justifierait :
# standard §17. (Le check-run garde le nom « CodeQL » : la règle de ruleset ci-dessous est
# inchangée.)
# ⚠ `gh api` écrit le corps JSON de l'erreur sur STDOUT, pas sur stderr. Un naïf
#   `DS=$(gh api … || echo unreadable)` produit donc « {"message":"403…"}unreadable » — une chaîne
#   qui n'est égale à RIEN, et tous les tests qui suivent partent dans le mauvais cas, en silence.
#   C'est le MÊME piège que celui déjà corrigé pour les rulesets (voir plus bas). On EXIGE donc un
#   JSON portant réellement `.state` avant de croire ce qu'on lit.
DS_RAW=$(gh api "repos/$SLUG/code-scanning/default-setup" 2>/dev/null || true)
if printf '%s' "$DS_RAW" | jq -e 'has("state")' >/dev/null 2>&1; then
  DS_STATE=$(printf '%s' "$DS_RAW" | jq -r '.state')
else
  DS_STATE=unreadable
fi
if [ "$DS_STATE" = "configured" ]; then
  echo "  ✓ CodeQL default setup déjà actif — langages détectés et TENUS À JOUR par GitHub."
elif [ "$DS_STATE" = "unreadable" ] && [ "$IS_PRIVATE" = "false" ]; then
  # NE PAS deviner. Sur un repo PUBLIC, cet endpoint DOIT répondre : s'il ne répond pas, c'est le
  # PAT qui manque `Administration` — et sans ce garde-fou le script enchaînerait sur un PATCH qui
  # échoue lui aussi, en accusant à tort « le default setup n'était pas configuré ».
  echo "  ⚠ état du default setup CodeQL ILLISIBLE sur un repo PUBLIC → le PAT manque 'Administration'."
  echo "    CodeQL ne sera NI activé NI vérifié. Corriger le PAT, puis REJOUER."
else
  # Un `codeql.yml` committé (repo d'AVANT ce changement) sera DÉSACTIVÉ par la bascule.
  # LE DIRE, jamais en silence : un fichier du repo cesse de tourner, et un workflow orphelin
  # qui traîne est un contrôle que plus personne ne lit.
  if gh api "repos/$SLUG/contents/.github/workflows/codeql.yml" >/dev/null 2>&1; then
    echo "  ⚠ ce repo porte un 'codeql.yml' committé → la bascule le passe en 'disabled_manually'."
    echo "    C'est VOULU : le default setup couvre PLUS de langages, et GitHub les tient à jour."
    echo "    → Le fichier devient MORT : le SUPPRIMER par une PR."
  fi
  # ⚠ LA SEULE ÉCRITURE DU SCRIPT QUI NE PASSE PAS PAR `mutate()` — et il faut savoir pourquoi.
  #   `mutate()` n'existe que pour intercepter ; il ne REND PAS la sortie de la commande. Or il nous
  #   faut ici le `run_id` que renvoie le PATCH. On garde donc le garde-fou du dry-run À LA MAIN.
  #   🔴 L'invariant « UN SEUL point d'interception » (cf. `mutate`) est donc FAUX À CET ENDROIT :
  #      la sûreté du dry-run y tient à ce `if`, et à lui seul. Toute édition future qui sortirait
  #      le PATCH de la branche `else` ÉCRIRAIT POUR DE VRAI, en silence, sur un repo vivant.
  if [ "$DRY" -eq 1 ]; then
    mutate gh api -X PATCH "repos/$SLUG/code-scanning/default-setup" -f state=configured
    # ⚠ LE DRY-RUN NE DOIT PAS MENTIR — il annonce ce qui SE PASSERAIT, pas ce qu'on espère.
    #   Il disait « ✓ ACTIVÉ » MÊME SUR UN REPO PRIVÉ, où le PATCH est voué à échouer (Advanced
    #   Security requis) : le script se contredisait DEUX LIGNES PLUS BAS (« CodeQL indisponible en
    #   privé »). Un dry-run qui promet un réglage impossible est pire qu'un dry-run muet : on le
    #   croit.
    if [ "$IS_PRIVATE" = "true" ]; then
      echo "  ↳ CodeQL : le PATCH ÉCHOUERA — indisponible sur un repo PRIVÉ (Advanced Security requis)."
      echo "    ATTENDU. CodeQL s'activera au REJEU de ce script APRÈS le flip public (§4)."
    else
      echo "  ✓ CodeQL default setup ACTIVÉ (langages auto-détectés)."
    fi
  else
    DS_RUN=$(gh_val '.run_id' '' -X PATCH "repos/$SLUG/code-scanning/default-setup" -f state=configured)
    # CEINTURE ET BRETELLES : un run_id est un ENTIER. Tout le reste — corps d'erreur, chaîne vide,
    # `null` — signifie que l'activation A ÉCHOUÉ. Sans ce filtre, un JSON d'erreur passait pour un
    # run_id, le script annonçait « ✓ ACTIVÉ » sur un repo où CodeQL est indisponible, et les deux
    # branches ci-dessous (privé / échec public) devenaient INATTEIGNABLES.
    case "$DS_RUN" in ''|*[!0-9]*) DS_RUN="" ;; esac
    if [ -n "$DS_RUN" ]; then
      echo "  ✓ CodeQL default setup ACTIVÉ — 1ʳᵉ analyse lancée (run $DS_RUN)."
      # 🔴 ATTENDRE — ce n'est PAS du confort. La règle 'code_scanning' n'est posée plus bas QUE si
      #    une analyse EXISTE. Sans cette attente, le script viendrait D'ACTIVER CodeQL, lirait
      #    « 0 analyse », et NE POSERAIT PAS la règle : `main` resterait NON PROTÉGÉE jusqu'à ce
      #    que quelqu'un pense à rejouer le script. Un trou de sécurité ouvert PAR LE SCRIPT.
      # ⚠ La boucle DOIT distinguer « pas encore fini » de « je n'ai pas le droit de regarder ».
      #   `gh api` écrivant ses erreurs sur STDOUT, un simple `= "completed"` ne voit JAMAIS la
      #   différence : sur un 403 il tournerait 36 × 10 s = SIX MINUTES, muet, pour finir par
      #   continuer sans savoir. On teste donc le statut CONTRE LA LISTE des valeurs valides.
      printf '    … attente de la 1ʳᵉ analyse — sans elle, la règle ne serait pas posée '
      DS_DONE=0; DS_BLIND=0
      for _ in $(seq 1 36); do
        RS=$(gh_val '.status' '' "repos/$SLUG/actions/runs/$DS_RUN")
        case "$RS" in
          completed) DS_DONE=1; break ;;
          queued|in_progress|requested|waiting|pending) DS_BLIND=0; printf '.'; sleep 10 ;;
          # ⚠ NE PAS conclure au 1er coup. GitHub met quelques secondes à MATÉRIALISER le run : un
          #   404 transitoire (ou un rate-limit) est NORMAL au début. Conclure immédiatement « le PAT
          #   manque Actions:read » serait un DIAGNOSTIC FAUX — le défaut que ce fichier passe son
          #   temps à traquer : accuser le PAT d'une permission qu'il possède. On tolère 3 réponses
          #   illisibles CONSÉCUTIVES avant de trancher.
          *) DS_BLIND=$((DS_BLIND + 1))
             if [ "$DS_BLIND" -ge 3 ]; then
               echo
               echo "  ⚠ run CodeQL ILLISIBLE (3 fois de suite) → le PAT admin manque « Actions: read »."
               echo "    Sans lui, impossible de savoir quand l'analyse se termine : la règle"
               echo "    'code_scanning' risque de NE PAS être posée, et 'main' de rester NON gardée."
               echo "    → Ajouter la permission au PAT, puis REJOUER."
               break
             fi
             printf '?'; sleep 10 ;;
        esac
      done
      [ "$DS_DONE" -eq 1 ] && echo " ok" || echo
    elif [ "$IS_PRIVATE" = "true" ]; then
      echo "  ↳ CodeQL indisponible sur ce repo PRIVÉ (Advanced Security requis) — ATTENDU, pas un échec."
      echo "    Il s'activera au REJEU de ce script APRÈS le flip public (§4). Le PAT n'est PAS en cause."
    else
      echo "  ⚠ activation du default setup ÉCHOUÉE sur un repo PUBLIC → CodeQL NE TOURNE PAS."
      echo "    Le PAT porte-t-il bien 'Administration: write' ? Corriger, puis REJOUER."
    fi
  fi
fi

# TROIS cas distincts, à ne JAMAIS confondre :
#   · liste JSON        → CodeQL a tourné : on sait combien d'analyses existent.
#   · 404 « no analysis found » → l'endpoint RÉPOND, il n'y a simplement AUCUNE analyse encore.
#   · 403 / autre       → on n'a PAS le droit de regarder (permission ou plan).
# Traiter le 404 comme un 403 fait accuser le PAT d'une permission qu'il possède — et envoie
# l'humain chercher un droit déjà présent.
CS_BODY=$(gh api "repos/$SLUG/code-scanning/analyses" 2>&1 || true)
if printf '%s' "$CS_BODY" | jq -e 'type == "array"' >/dev/null 2>&1; then
  ANALYSES=$(printf '%s' "$CS_BODY" | jq 'length')
  CS_READABLE=1
elif printf '%s' "$CS_BODY" | grep -q "no analysis found"; then
  ANALYSES=0          # l'endpoint répond : il n'y a juste rien encore
  CS_READABLE=1
else
  ANALYSES=0
  CS_READABLE=0       # 403 : droit manquant, ou feature indisponible sur ce plan
fi
read -r -d '' RULESET_JSON <<JSON || true
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
    } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": false,
        "required_status_checks": $CHECKS_JSON
    } }
  ]
}
JSON

# Règle code_scanning : ajoutée SEULEMENT si CodeQL a déjà produit une analyse.
CS_RULE='{"type":"code_scanning","parameters":{"code_scanning_tools":[
  {"tool":"CodeQL","security_alerts_threshold":"high_or_higher","alerts_threshold":"errors"}]}}'
if [ "$CS_READABLE" -eq 0 ] && [ "$IS_PRIVATE" = "true" ]; then
  echo "  ↳ CodeQL indisponible en privé (Advanced Security requis) → règle 'code_scanning' non posée."
  echo "    ATTENDU. Elle sera posée au flip public, dès la 1ʳᵉ analyse. Le PAT n'est PAS en cause."
elif [ "$CS_READABLE" -eq 0 ]; then
  echo "  ⚠ analyses CodeQL ILLISIBLES sur un repo PUBLIC → le PAT admin manque « Code scanning alerts: read »."
  echo "    La règle 'code_scanning' n'est donc PAS posée : CodeQL ne bloquera PAS les PR."
  echo "    → Ajouter cette permission (lecture seule) au PAT et REJOUER."
elif [ "$ANALYSES" -gt 0 ]; then
  RULESET_JSON=$(printf '%s' "$RULESET_JSON" | jq -c --argjson r "$CS_RULE" '.rules += [$r]')
  echo "  ↳ CodeQL a produit $ANALYSES analyse(s) → règle 'code_scanning' posée : une alerte bloque la PR."
else
  # Ce cas ne devrait PLUS se produire sur un repo public : le script vient d'activer le default
  # setup ET d'attendre sa 1ʳᵉ analyse. S'il tombe ici, c'est que l'ANALYSE A ÉCHOUÉ — ce n'est
  # donc pas « pas encore », c'est « ça ne marche pas », et il faut le dire ainsi.
  echo "  ⚠ AUCUNE analyse CodeQL malgré l'activation → la règle 'code_scanning' n'est PAS posée."
  echo "    'main' n'est donc PAS gardée par CodeQL. Regarder le run 'CodeQL Setup' dans Actions,"
  echo "    puis REJOUER ce script une fois l'analyse verte."
fi

# ⚠ En cas d'erreur HTTP (403 « Upgrade to GitHub Pro » sur un repo PRIVÉ en Free), `gh api`
# écrit le corps JSON de l'erreur sur STDOUT. Sans ce garde-fou, ce JSON était avalé comme si
# c'était un ID de ruleset, puis recollé dans l'URL du PUT → erreur incompréhensible.
# On exige donc une VRAIE liste JSON avant d'aller plus loin.
RULESETS=$(gh api "repos/$SLUG/rulesets" 2>/dev/null || true)
if ! printf '%s' "$RULESETS" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "  ⚠ rulesets INDISPONIBLES sur ce repo — attendu sur un repo PRIVÉ en plan Free (standard §18)."
  echo "    'main' n'est donc PAS protégée : ni PR obligatoire, ni checks requis, force-push possible."
  echo "    Les TAGS ne sont pas protégés non plus → le pin de version en prod (§13) ne garantit rien."
  echo "    → REJOUER ce script au passage en public (procédure complète : standard §18)."
  RULESETS=""
fi

# upsert_ruleset <nom> <json> — create si absent, update sinon. IDEMPOTENT.
#   · Les règles d'un type que CE ruleset ne gère pas (ex. `code_quality` posé à la main, ou
#     `code_scanning` quand CodeQL n'a pas encore tourné) sont PRÉSERVÉES : le périmètre géré est
#     déduit des types présents dans le JSON fourni, pas d'une liste figée qui dériverait.
#   · Fusion DÉDUPLIQUÉE par type → aucun doublon au rejeu.
#   · bypass_actors : jamais supprimés en silence (le standard n'en veut aucun, mais c'est à
#     l'humain de trancher).
upsert_ruleset() {
  RS_NAME="$1"; RS_JSON="$2"
  [ -n "$RULESETS" ] || return 0

  RS_ID=$(printf '%s' "$RULESETS" | jq -r --arg n "$RS_NAME" '.[] | select(.name==$n) | .id' | head -n1)
  case "$RS_ID" in (''|*[!0-9]*) RS_ID="" ;; esac   # ne poursuivre que sur un ID numérique

  if [ -z "$RS_ID" ]; then
    printf '%s' "$RS_JSON" | mutate gh api -X POST "repos/$SLUG/rulesets" --input - >/dev/null \
      && echo "  ✓ ruleset '$RS_NAME' créé" \
      || echo "  ⚠ ruleset '$RS_NAME' : création refusée"
    return 0
  fi

  RS_CUR=$(gh api "repos/$SLUG/rulesets/$RS_ID")
  RS_KEPT=$(printf '%s' "$RS_CUR" | jq -c --argjson mine "$(printf '%s' "$RS_JSON" | jq -c '.rules')" \
            '[.rules[]? | select(.type as $t | ($mine | map(.type) | index($t)) | not)]')
  RS_NKEPT=$(printf '%s' "$RS_KEPT" | jq 'length')
  [ "$RS_NKEPT" -gt 0 ] && \
    echo "  ↳ '$RS_NAME' : $RS_NKEPT règle(s) hors périmètre préservée(s) : $(printf '%s' "$RS_KEPT" | jq -r '[.[].type] | join(", ")')"

  RS_NBYP=$(printf '%s' "$RS_CUR" | jq '[.bypass_actors[]?] | length')
  if [ "$RS_NBYP" -gt 0 ]; then
    echo "  ⚠ '$RS_NAME' : $RS_NBYP bypass_actor(s) — le standard n'en veut aucun."
    echo "    Ils NE seront PAS supprimés automatiquement. Les retirer à la main si voulu."
    RS_JSON=$(printf '%s' "$RS_JSON" | jq -c --argjson b "$(printf '%s' "$RS_CUR" | jq -c '.bypass_actors')" '.bypass_actors = $b')
  fi

  printf '%s' "$RS_JSON" | jq -c --argjson kept "$RS_KEPT" '.rules += $kept' \
    | mutate gh api -X PUT "repos/$SLUG/rulesets/$RS_ID" --input - >/dev/null \
    && echo "  ✓ ruleset '$RS_NAME' mis à jour (#$RS_ID) — règles du script appliquées, le reste intact"
}

# ⚠ SQUASH-ONLY et branche de STAGING sont INCOMPATIBLES.
#   Squasher `develop` dans `main` réécrit les commits : les deux branches divergent alors à CHAQUE
#   cycle (mêmes changements, SHA différents), et l'historique des `feat/*` est perdu.
#   → Si `develop` existe, `main` accepte AUSSI le merge commit (c'est ce que prescrit le §12 pour
#     la promotion staging → prod). `develop`, elle, reste en squash seul : les `feat/*` y sont
#     écrasés en un commit propre.

# ⚠️ LA PROMOTION EN PROD DÉTRUIT LE STAGING — et le script en était la victime silencieuse.
#   `delete_branch_on_merge` (posé plus haut, et utile pour les `feat/*`) supprime la branche SOURCE
#   de TOUTE PR mergée — donc `develop` elle-même, au merge de la PR `develop → main` du §12.
#   En PUBLIC, le ruleset 'develop' (règle `deletion`) l'en empêche. En PRIVÉ, il n'y a AUCUN
#   ruleset : la 1ʳᵉ mise en production SUPPRIME la branche de staging, sans un mot.
#
#   Le script déduisait le staging de l'EXISTENCE de `develop`. Disparue, il concluait « pas de
#   staging » et alignait tout dessus : pas de ruleset 'develop', et `main` REPASSAIT en squash-only
#   — rendant la promotion suivante IMPOSSIBLE. Un dégât en cascade, déclenché par le succès.
#
#   → On ne fait donc plus confiance à la seule existence de la branche : on demande AUSSI au repo ce
#     qu'il PUBLIE (`WANTS_STAGING`, sondé en tête avec `HAS_DEVELOP`).
if [ "$WANTS_STAGING" -eq 1 ] && [ "$HAS_DEVELOP" -eq 0 ]; then
  echo "  ⚠ INCOHÉRENCE — le repo PUBLIE un flux à 3 ÉTAGES, mais la branche 'develop' N'EXISTE PAS."
  echo "    Cause quasi certaine : 'delete-branch-on-merge' l'a SUPPRIMÉE au merge de la PR develop → main."
  echo "    En PRIVÉ, aucun ruleset ne la protège : la mise en production DÉTRUIT le staging."
  echo "    Sans elle : pas de ruleset 'develop', et 'main' retombe en SQUASH-ONLY — donc la"
  echo "    promotion suivante devient IMPOSSIBLE (squasher develop dans main les fait diverger, §12)."
  echo "    → LA RECRÉER, PUIS REJOUER CE SCRIPT :"
  echo "        git switch -c develop main && git push -u origin develop"
  echo "      Le ruleset 'develop' (règle 'deletion') l'empêchera alors d'être supprimée à nouveau."
fi

# ⚠️ LE MÊME RÉGLAGE, MAIS PRIS EN AMONT — parce qu'AVERTIR N'A PAS SUFFI.
#   Le bloc au-dessus ne parle qu'APRÈS le dégât, et seulement si on rejoue ce script. Or la perte
#   est CERTAINE et AUTOMATIQUE : `delete_branch_on_merge` vise la branche SOURCE de la PR, et la
#   source d'une promotion §12 EST `develop`. Ce qui la sauve en PUBLIC, c'est le ruleset (sa règle
#   `deletion` : GitHub ne supprime jamais une branche protégée, même avec l'option activée). En
#   PRIVÉ Free il n'y a AUCUN ruleset — donc aucun garde-fou, et avertir ne suffit pas.
#   → Ici on RETIRE le réglage. Ce qu'on perd est le nettoyage automatique des `feat/*` — du
#     confort, un clic — contre une branche long-lived détruite en silence, qui casse la promotion
#     SUIVANTE (sans `develop`, ce script conclut « pas de staging » et `main` retombe en
#     squash-only). Le flip en public le rétablit : rejouer ce script, le ruleset prend le relais.
# Dependabot security updates : ses PR visent TOUJOURS la branche par défaut — sur 3 étages elles
# court-circuiteraient le staging. Le §3a ne les pose donc plus ici ; ce bloc RETIRE l'état ANTÉRIEUR
# (repo configuré avant ce changement, ou activé à la main), et seulement si Renovate est PROUVÉ
# vivant. Le pourquoi et le seuil : standard, « Qui met à jour les dépendances ».
#   ⚠ La FRAÎCHEUR, pas l'existence : un repo opted-out garde son Dependency Dashboard intact.
#     Sonder `.updated_at` est le seul signal qui distingue un bot qui tourne d'un bot mort.
if [ "$HAS_DEVELOP" -eq 1 ] || [ "$WANTS_STAGING" -eq 1 ]; then
  DASH_RC=0
  DASH_AT=$(gh api "repos/$SLUG/issues?state=open&per_page=100" \
    --jq 'map(select(.title=="Dependency Dashboard"))|.[0].updated_at // empty' 2>/dev/null) || DASH_RC=$?
  # ⚠ `gh api` écrit son JSON d'erreur sur STDOUT : sans ce filtre de FORME, un `{"message":"Not Found"}`
  #   comparé à une date ISO est jugé PLUS RÉCENT (`{` > `2` en ASCII) — une panne de lecture RETIRERAIT
  #   le filet. Mesuré : c'est ce que renvoie un `$SLUG` vide.
  #   Le code de sortie est gardé À PART : sans lui, « refusé » et « absent » se ressemblent, et une
  #   permission manquante enverrait chercher du côté de Renovate — la panne silencieuse qu'on interdit.
  case "$DASH_AT" in 20[0-9][0-9]-*) ;; *) DASH_AT="" ;; esac
  # `date -v` (BSD/macOS) puis `date -d` (GNU) : le script tourne des deux côtés.
  FRESH=$(date -u -v-14d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ)
  if [ -n "$DASH_AT" ] && [[ "$DASH_AT" > "$FRESH" ]]; then
    mutate gh api -X DELETE "repos/$SLUG/automated-security-fixes" >/dev/null 2>&1 \
      && echo "  ✓ Dependabot security updates RETIRÉ — 3 étages, Renovate vivant (dashboard $DASH_AT)" \
      || echo "  ⚠ DELETE automated-security-fixes : échec — vérifier Settings → Advanced Security."
  else
    echo "  ⚠ Dependabot security updates CONSERVÉ — 3 étages, mais Renovate NON prouvé vivant."
    echo "    Ses PR sécu viseront 'main', court-circuitant 'develop'. Cause et geste :"
    if [ "$DASH_RC" -ne 0 ]; then
      echo "    → LECTURE REFUSÉE (issues illisibles). Le PAT admin manque 'Issues: Read' — la recette"
      echo "      complète est dans docs/RUNBOOK.md. Le corriger, puis REJOUER."
    elif [ -z "$DASH_AT" ]; then
      echo "    → AUCUN 'Dependency Dashboard' : l'app Renovate n'est pas installée sur ce repo."
      echo "      L'installer (UI GitHub), attendre son 1er run, puis REJOUER."
    else
      echo "    → Dashboard PÉRIMÉ ($DASH_AT, seuil $FRESH) : Renovate est installé mais ne tourne plus."
      echo "      Vérifier qu'aucune PR d'onboarding n'a été fermée (opt-out documenté du bot)."
    fi
  fi
fi

if { [ "$WANTS_STAGING" -eq 1 ] || [ "$HAS_DEVELOP" -eq 1 ]; } && [ -z "$RULESETS" ]; then
  mutate gh repo edit "$SLUG" --delete-branch-on-merge=false
  echo "  ⚠ 'delete-branch-on-merge' RETIRÉ — flux à 3 étages SANS ruleset (privé Free) : il"
  echo "    supprimerait 'develop' à la 1ʳᵉ promotion. Les 'feat/*' sont à supprimer à la main."
  echo "    Au passage en PUBLIC, rejouer ce script : le ruleset 'develop' protège, on le remet."
fi

if [ "$HAS_DEVELOP" -eq 1 ]; then
  RULESET_JSON=$(printf '%s' "$RULESET_JSON" | jq -c \
    '(.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods) = ["squash","merge"]')
  mutate gh repo edit "$SLUG" --enable-merge-commit >/dev/null 2>&1 \
    && echo "  ↳ 'develop' existe → 'main' accepte AUSSI le merge commit (promotion staging → prod, §12)."
fi

upsert_ruleset "$RULESET_NAME" "$RULESET_JSON"

# 6b. Ruleset 'develop' — SEULEMENT si la branche existe (capacité STAGING, standard §12).
if [ -n "$RULESETS" ] && gh api "repos/$SLUG/branches/develop" >/dev/null 2>&1; then
  DEV_JSON=$(printf '%s' "$RULESET_JSON" | jq -c \
    '.name = "develop"
     | .conditions.ref_name.include = ["refs/heads/develop"]
     | .rules = [ .rules[] | select(.type != "code_scanning") ]
     | (.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods) = ["squash"]')
  upsert_ruleset "develop" "$DEV_JSON"
fi

# 6c. Ruleset TAGS — c'est CE contrôle qui rend le pin de version du §13 réel.
#     Sans lui, un tag `v1.2.3` peut être DÉPLACÉ ou SUPPRIMÉ : la prod épingle `APP_IMAGE_TAG=1.2.3`
#     en croyant figer un artefact, alors que le tag peut pointer ailleurs demain. Le pin ne vaut
#     que si le tag est immuable.
read -r -d '' TAGS_JSON <<'JSON' || true
{
  "name": "tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [ { "type": "deletion" }, { "type": "update" }, { "type": "non_fast_forward" } ]
}
JSON
upsert_ruleset "tags" "$TAGS_JSON"

# 6c. BRANCH PROTECTION *CLASSIQUE* — l'AUTRE système, que `GET /rulesets` NE MONTRE PAS.
#     Un repo existant peut en porter une, héritée, qui exige des checks nommés d'après SES anciens
#     jobs. En adoptant les workflows du template, ces checks CESSENT D'EXISTER : la règle survit et
#     réclame pour toujours un statut que plus rien ne produira — la branche est VERROUILLÉE, CI
#     verte ou pas, et `gh pr merge` répond seulement « base branch policy prohibits the merge ».
#     Les deux systèmes se CUMULENT : poser le ruleset ne neutralise pas l'ancienne règle.
# ⚠ On DÉTECTE et on DIT — on ne supprime pas : la règle classique peut porter des réglages que le
#   ruleset ne réplique pas, et détruire une protection est un geste de Romain (comme la visibilité).
for BR in main develop; do
  gh api "repos/$SLUG/branches/$BR/protection" >/dev/null 2>&1 || continue
  CTX=$(gh api "repos/$SLUG/branches/$BR/protection" \
          --jq '[.required_status_checks.contexts[]?] | join(", ")' 2>/dev/null || true)
  echo "  ⚠ branch protection CLASSIQUE encore active sur '$BR'${CTX:+ — checks exigés : $CTX}."
  echo "    Elle s'AJOUTE au ruleset qu'on vient de poser. Si elle exige un check DISPARU"
  echo "    (jobs renommés en adoptant les workflows du template), AUCUNE PR ne passera JAMAIS."
  echo "    → la retirer maintenant que le ruleset protège : https://github.com/$SLUG/settings/branches"
done

# 7. CONTRÔLE FINAL — community profile.
#    Le score est le seul indicateur des réglages que l'API n'expose PAS (« Reported content » :
#    ni REST ni GraphQL). Sans ce contrôle,
#    un item manquant reste invisible : le script dirait « tout est appliqué » et ce serait faux.
PROFILE=$(gh api "repos/$SLUG/community/profile" 2>/dev/null || true)
if printf '%s' "$PROFILE" | jq -e '.health_percentage' >/dev/null 2>&1; then
  HEALTH=$(printf '%s' "$PROFILE" | jq '.health_percentage')
  # `issue_template` est TOUJOURS null quand les templates sont en dossier (artefact d'API,
  # sans effet sur le score) → l'exclure, sinon on signale un manque qui n'existe pas.
  MISSING=$(printf '%s' "$PROFILE" | jq -r '[.files | to_entries[]
              | select(.value == null)
              | select(.key | IN("issue_template","code_of_conduct_file") | not) | .key]
              + (if .description == null then ["description"] else [] end)
              + (if .documentation == null then ["documentation (homepage)"] else [] end)
              | join(", ")')
  if [ "$HEALTH" -ge 100 ]; then
    echo "  ✓ community profile : 100 %"
  else
    echo "  ⚠ community profile : $HEALTH % — incomplet."
    [ -n "$MISSING" ] && echo "    Fichiers/champs manquants : $MISSING"
    if [ -z "$MISSING" ]; then
      # Tous les fichiers sont là mais le score n'est pas plein → c'est l'item UI-only, qui
      # n'existe QUE sur les repos d'ORGANISATION (checklist à 8 items au lieu de 7).
      echo "    Tous les fichiers sont présents → il reste l'item NON SCRIPTABLE :"
      echo "    Settings > Moderation options > Reported content > 'Prior contributors and collaborators'"
      echo "    https://github.com/$SLUG/settings/moderation/reported-content"
      echo "    (Aucune API, ni REST ni GraphQL. Le défaut GitHub ne s'applique PAS à un repo"
      echo "     créé PRIVÉ puis passé public — exactement notre cas.)"
    fi
  fi
fi

echo "✓ $SLUG : réglages serveur appliqués."
echo
echo "  ⚠️  RÉVOQUER LE PAT ADMIN MAINTENANT — il n'a plus aucune raison d'exister :"
echo "     https://github.com/settings/personal-access-tokens"
echo
if gh api "repos/$SLUG/contents/.github/workflows/docker-publish.yml" >/dev/null 2>&1; then
# VERIFIER au lieu de RAPPELER. Un job "Publish image" VERT ne prouve PAS que l'image est
# tirable. Ce test interroge le registre EXACTEMENT comme le host de prod :
# anonymement, sans aucun token. C'est la seule preuve qui compte.
# (L'API packages est hors de portee : les PAT fine-grained ne supportent PAS ghcr — classic only.)
# TROIS états, pas deux. Un booléen `PULL_OK` confondait « testé et ÉCHOUÉ » avec « PAS TESTABLE »,
# et réclamait donc de rendre public un package QUI N'EXISTE PAS ENCORE — sur un repo neuf, sans la
# moindre release. Réclamer un geste sur un objet inexistant, c'est le défaut du BUG 4 qui se rejoue :
# PARLER SANS SAVOIR. Et le bruit a un coût : il finit par noyer le rappel de RÉVOQUER LE PAT ADMIN.
PULL_STATE=untested
if [ "$IS_PRIVATE" = "false" ] && [ "$(gh_val 'length' 0 "repos/$SLUG/releases")" -gt 0 ]; then
  TAG=$(gh api "repos/$SLUG/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//')
  # Le nom du package ghcr N'EST PAS déductible du slug. Il coïncide sur un projet GÉNÉRÉ
  # (init-project.sh substitue `<image-name>` par le nom du repo) — d'où un bug longtemps invisible.
  # Un repo MIGRÉ publie sous le nom qu'il veut (`DecantFi` → `decantfi-collector`) : le déduire
  # faisait tester un package INEXISTANT, donc annoncer « image NON TIRABLE, le pin de prod ne vaut
  # rien » et réclamer de rendre public un objet qui n'existe pas. On LIT la source de vérité — le
  # `images:` du workflow — et on retombe sur le slug si elle est illisible (fix strictement additif).
  # `Accept: raw` évite un décodage base64 (`-d` GNU vs `-D` BSD ne sont pas portables).
  IMG_NAME=$(gh api -H "Accept: application/vnd.github.raw" \
      "repos/$SLUG/contents/.github/workflows/docker-publish.yml" 2>/dev/null \
    | sed -n 's|^[[:space:]]*images:[[:space:]]*ghcr\.io/[^/]*/\([A-Za-z0-9._-][A-Za-z0-9._-]*\).*|\1|p' \
    | head -1)
  # ghcr n'accepte QUE des minuscules : `actarus314/DecantFi` interroge un chemin qui n'existe pas.
  IMG=$(printf '%s/%s' "${SLUG%%/*}" "${IMG_NAME:-${SLUG##*/}}" | tr '[:upper:]' '[:lower:]')
  ATOK=$(curl -s "https://ghcr.io/token?scope=repository:${IMG}:pull&service=ghcr.io" \
    | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
  ACODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${ATOK}" \
    -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/${IMG}/manifests/${TAG}" 2>/dev/null || echo 000)
  if [ "$ACODE" = "200" ]; then
    PULL_STATE=ok
    echo "  ✓ image ghcr TIRABLE anonymement (${IMG}:${TAG}) — le host de prod peut la pull."
  else
    PULL_STATE=ko
    echo "  ⚠ image ghcr NON TIRABLE anonymement (${IMG}:${TAG} → HTTP ${ACODE})."
    echo "    Le host de PROD ne peut PAS la pull : le pin de version du §13 ne vaut RIEN."
    echo "    Cause quasi certaine : le package ghcr est PRIVE."
  fi
fi
# PAS ENCORE D'IMAGE : on INFORME, on ne réclame RIEN. Le geste, s'il est nécessaire, le sera à la
# 1ʳᵉ release — et c'est là que le RUNBOOK §3 le rappelle, au moment où l'objet existe enfin.
if [ "$PULL_STATE" = "untested" ]; then
  if [ "$IS_PRIVATE" = "true" ]; then
    echo "  ↳ repo PRIVÉ : la visibilité du package ghcr ne se pose pas encore. Elle se posera au flip."
  else
    echo "  ↳ aucune release ⇒ AUCUNE image ghcr n'existe encore : rien à rendre public aujourd'hui."
    echo "    À la 1ʳᵉ release, ce script REJOUÉ testera le pull anonyme et le dira (RUNBOOK §3)."
  fi
fi
# ⚠️ Le rappel « rendre le package public » ne s'affiche QUE si le pull anonyme n'est PAS prouvé.
#   Le défaut N'EST PAS universel : sur un compte PERSO, un package publié depuis un repo PUBLIC
#   hérite de son accès et est tirable AUSSITÔT. Sur une ORG, il peut être PRIVÉ (défaut d'org).
#   → On ne SUPPOSE plus : on TESTE, et on ne parle que si ça rate.
if [ "$PULL_STATE" = "ko" ]; then
  echo "  À FAIRE À LA MAIN — visibilité du package ghcr (aucune API : les PAT fine-grained ne"
  echo "  couvrent PAS ghcr, seuls les PAT classic le font)."
  echo "     -> Package settings > Danger Zone > Change visibility > Public"
  # L'URL des packages DIFFÈRE selon le type de compte : /orgs/<o>/… en organisation,
  # /users/<o>/… sur un compte perso.
  OWNER_TYPE=$(gh_val '.type' 'Organization' "users/${SLUG%%/*}")
  if [ "$OWNER_TYPE" = "User" ]; then PKG_NS="users"; else PKG_NS="orgs"; fi
  # Le nom du package vient d'`images:` (cf. plus haut), JAMAIS du slug : `DecantFi` publie
  # sous `decantfi-collector`. Le déduire donnait une URL 404 — précisément au moment où ce
  # rappel compte. `IMG` est en portée : PULL_STATE=ko n'est posé que là où il est calculé.
  echo "     https://github.com/$PKG_NS/${SLUG%%/*}/packages/container/${IMG#*/}/settings"
  echo "     Sans ce geste, le pull anonyme renvoie 403 : ni le host de prod ni un"
  echo "     utilisateur ne peuvent tirer l'image."
  echo "     Org-wide : Settings > Packages > Package creation > default visibility."
fi
fi
