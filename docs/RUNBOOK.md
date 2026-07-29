# Runbook — le cycle de vie d'un projet, de bout en bout

> **Ce document dit l'ORDRE DES GESTES et QUI les fait. Le standard dit le POURQUOI.**
> Chaque étape renvoie à la section qui l'explique — on ne recopie pas le raisonnement ici.
>
> 🔴 **SOURCE DE VÉRITÉ — les tables de permissions des PAT (§1) FONT FOI.** Elles sont *aussi* dans
> `github-repo-config.md §2`, qui explique **d'où chaque permission est dérivée** (un endpoint appelé
> = une permission). **En cas d'écart : ce document gagne, et l'écart est un DÉFAUT à corriger** —
> deux copies divergent toujours, et une permission manquante **échoue en SILENCE**.
> Standard : `claude-code-project-standard.md` · Config serveur : `github-repo-config.md` · Contrôles : `controles-repo.md`

**Deux règles qui traversent tout le document :**

| | |
|---|---|
| 🔴 **L'assistant n'a JAMAIS `Administration`** | Tout ce qui touche rulesets / visibilité / Pages / secret scanning est **fait par Romain**, avec un **PAT admin ÉPHÉMÈRE** créé puis **révoqué dans la foulée**. |
| 🔴 **Le cycle nominal est : PRIVÉ → développé → PUBLIC** | Un repo privé en plan Free n'a **ni ruleset, ni secret scanning, ni CodeQL**. Les contrôles **tournent** mais **rien ne les exige**. Le flip les active **tous d'un coup**. |

---

## 1 · Créer un projet

**Se poser les trois questions AVANT de taper la commande** — elles décident de tout *(standard §12)* :

| | Question | Flag |
|---|---|---|
| **a** | Le site sera-t-il servi par **GitHub Pages** ? | `--pages` |
| **b** | Le repo **publiera-t-il une image que quelqu'un d'AUTRE déploie** ? *(auto-hébergeurs, NUC…)* | `--artefact` |
| **c** | Existe-t-il un **host à VALIDER** avant la prod ? | `--staging` |

> **`develop` découle de (c), jamais de Docker ni du langage.** Un projet `node` sans host à valider n'en a pas ; un site Pages packagé en image non plus.

### 🔴 Étape 1 — Romain : créer le repo (UI)

**→ https://github.com/new**

- **Visibility : PRIVATE.** *(Le cycle nominal. Il passera public plus tard — §4.)*
- **Ne rien cocher** : ni README, ni .gitignore, ni licence. `init-project.sh` les pose, et un fichier créé par GitHub ferait diverger le premier commit.

### Étape 2 — Claude : générer le projet

```bash
./init-project.sh <projet> <owner>/<repo> [--type static|node|generic] [--pages] [--artefact] [--staging]
```

Crée l'arborescence, le premier commit, le remote en **URL nue**, et un **`.envrc` VIDE** *(le PAT n'existe pas encore)*.

> ⚠️ `repo/.envrc` **n'existe pas** tant que ce script n'a pas tourné : rien à y coller avant l'étape 3.

### 🔴 Étape 3 — Romain : créer le PAT d'écriture (celui de l'assistant)

**→ https://github.com/settings/personal-access-tokens/new**

| Réglage | Valeur |
|---|---|
| **Token name** | `claude-<repo>` |
| **Expiration** | **90 jours** *(Claude alerte à J-14 — §6)* |
| **Resource owner** | l'owner du repo *(perso ou l'org)* |
| **Repository access** | ⚠️ **Only select repositories → CE repo, et lui seul.** *Blast radius = 1 repo.* |

**Repository permissions** — *exactement celles-ci, rien de plus* :

| Permission | Niveau | Pourquoi |
|---|---|---|
| **Contents** | Read and write | pousser, brancher, merger |
| **Pull requests** | Read and write | ouvrir et merger les PR |
| **Issues** | Read and write | |
| **Workflows** | Read and write | éditer les YAML de CI |
| **Actions** | Read and write | relancer / annuler un run |
| **Dependabot alerts** | Read and write | traiter les alertes **en autonomie** |
| **Code scanning alerts** | Read and write | idem |
| **Secret scanning alerts** | **Read** *(pas write)* | 🔴 **le dismiss est réservé à Romain** — rejeter à tort une vraie fuite a trop d'impact |
| *Metadata* | *Read* | *coché automatiquement* |

> 🔴 **`Administration` : JAMAIS.** C'est toute la matrice de sécurité. **Tout le reste : No access.**

### 🔴 Étape 4 — Romain : coller le PAT, puis **`direnv allow`**

```bash
cd <dossier-projet>/repo
$EDITOR .envrc          # remplir la ligne : export GITHUB_PAT=github_pat_xxxxx
direnv allow            # ⚠️ OBLIGATOIRE — voir ci-dessous
```

> 🔴 **`direnv allow` n'est PAS optionnel, et le piège est subtil.**
> `init-project.sh` a déjà fait un `direnv allow` — **mais sur un `.envrc` VIDE**. En y collant le PAT, **tu modifies le fichier**, et direnv **révoque automatiquement** son autorisation *(c'est sa sécurité : il refuse d'exécuter un fichier modifié sans accord explicite)*.
> **Sans ce second `direnv allow`, le `.envrc` n'est jamais chargé** → `GITHUB_PAT` reste vide → **`git push` échoue en 403**, alors que le token est bien dans le fichier. **Symptôme parfaitement déroutant.**

**Vérifier que ça a pris** *(le PAT ne doit JAMAIS être affiché — on ne teste qu'un booléen)* :
```bash
cd <dossier-projet>/repo && [ -n "$GITHUB_PAT" ] && echo "PAT chargé ✓" || echo "PAT ABSENT ✗ → direnv allow"
```

- **Jamais dans `.env`** *(fuite conteneur via `env_file`)*. **Jamais dans l'URL du remote** *(fuite en clair dans `.git/config`)*.
- *(Si `direnv` n'est pas installé : `brew install direnv` + le hook dans `~/.zshrc`.)*
- 💡 **L'outil Bash de Claude lance un shell NON-interactif : direnv n'y tourne pas.** `init-project.sh` a donc posé un **credential helper local** qui lit `$GITHUB_PAT` — c'est ce qui permet à l'assistant de pousser malgré tout. **Ton `direnv allow` reste indispensable** : c'est lui qui met le PAT dans l'environnement.

### Étapes 5 et 6 — Claude

| # | Geste |
|---|---|
| 5 | **Remplir ce que le script signale** : `<contact>` dans `SECURITY.md` · les champs de `AGENTS.md` · le titulaire de `LICENSE`. |
| 6 | Premier push : `git push -u origin main` *(le hook `pre-push` laisse passer la **création** d'une branche)*. Puis `git push -u origin develop` **si `--staging`**. |

### 🔴 Étape 7a — Romain : créer le PAT ADMIN **ÉPHÉMÈRE**

**→ https://github.com/settings/personal-access-tokens/new**

| Réglage | Valeur |
|---|---|
| **Token name** | `admin-<repo>-jetable` |
| **Expiration** | **la plus courte possible** *(7 jours)* — il sera de toute façon **révoqué dans 5 minutes** |
| **Repository access** | ⚠️ **Only select repositories → CE repo** |

**Repository permissions** — *la recette COMPLÈTE, dérivée des endpoints appelés* :

| Permission | Niveau | Pourquoi |
|---|---|---|
| **Administration** | **Read and write** | `PATCH /repos` · `PUT /vulnerability-alerts` · `*/rulesets` · `PUT /immutable-releases` |
| **Pages** | **Read and write** | création du site Pages |
| **Code scanning alerts** | **Read** | savoir si CodeQL a produit une analyse |
| **Actions** | **Read** | 🔴 **suivre le run de la 1ʳᵉ analyse CodeQL.** Sans elle, le script ne sait pas quand l'analyse finit → il **ne pose pas la règle `code_scanning`**, et `main` reste **NON gardée**. |
| **Contents** | **Read** | détecter `pages.yml` / `docker-publish.yml` · lire `CONTRIBUTING.md` *(le repo publie-t-il 3 étages ?)* |
| **Issues** | **Read** | 🔴 **preuve de vie de Renovate** — `GET /repos/{o}/{r}/issues`, pour dater son *Dependency Dashboard* avant de retirer le filet Dependabot d'un flux à 3 étages. Sans elle, le script **conserve** le filet *(ses PR sécu continueront de viser `main`)* — il le dit et nomme cette permission. *(La table officielle liste cet endpoint sous `Issues: read` **et** sous `Pull requests: read` — l'une **ou** l'autre suffit ; on prend `Issues`, c'est ce qu'on lit.)* |
| *Metadata* | *Read* | *automatique* |

> ⚠️ **`Administration` NE SUFFIT PAS**, et **chaque permission manquante échoue en SILENCE** : tout le reste passe, et le contrôle absent ne se voit pas. **La recette se DÉRIVE des endpoints appelés — jamais par essais successifs.**
> **Ce token n'est stocké NULLE PART** : ni keychain, ni `.envrc`, ni historique shell. Le script le demande en **saisie masquée**.

### Étape 7b — Romain : jouer le script

```bash
cd ~/Documents/Claude/template/repo
./configure-repo.sh <owner>/<repo> '' 'Description du projet en une ligne.' 'topic-a,topic-b'
#                                   ↑ homepage : vide ici, le script la déduira de Pages au flip
#                                                                            ↑ topics : csv, facultatif
```

> 🔴 **Sur un repo qui EXISTAIT déjà, le script peut signaler une « branch protection CLASSIQUE encore active ».** C'est l'**ancien** système de protection, que l'API `rulesets` **ne montre pas** — et il se **cumule** avec le ruleset. S'il exige un check nommé d'après un job qui a disparu *(ce qui arrive dès qu'on adopte les workflows du template)*, **plus aucune PR ne peut jamais être mergée**, CI verte ou pas, avec le seul message « base branch policy prohibits the merge ».
> **→ La retirer MAINTENANT** *(le ruleset vient d'être posé : la branche n'est jamais sans protection)* : https://github.com/&lt;owner&gt;/&lt;repo&gt;/settings/branches — section **« Branch protection rules »**, à distinguer de la section **« Rulesets »** juste en dessous. *(Le badge « Protected » s'allume pour les deux : regarder la SECTION, pas le badge.)*

> **La description ET les topics exigent `Administration:write`** — l'assistant, qui n'a **jamais** cette permission, reçoit un **403**. **Seul ce script peut les poser.**
> Sans description, le community health **plafonne à 85 %**. Sans topic, le repo **ne remonte dans aucune recherche GitHub par sujet**. Le script **le signale** dans les deux cas au lieu de laisser le trou passer.

Le script **demande le PAT en saisie masquée** *(il n'apparaît ni à l'écran, ni dans l'historique, ni dans `ps`)*.

- **Sur un repo PRIVÉ/Free, il pose ce qu'il peut** : **Dependabot alerts** *(partout — Renovate les lit)*, les **security updates** *(filet — **2 étages seulement**)*, description, méthode de merge, `default_workflow_permissions`.
- 🔴 **Sur un flux à 3 ÉTAGES, le REJOUER une fois l'app Renovate installée.** Le script ne retire le filet Dependabot *(dont les PR sécu visent `main`, court-circuitant le staging)* qu'en voyant Renovate **vivant** — son *Dependency Dashboard* daté de moins de 14 jours. Joué **avant** l'onboarding, il ne trouve aucun dashboard, **conserve** le filet et **le dit** : ce message est l'invitation à le rejouer, pas un échec.
- **Il annonce que rulesets / secret scanning / CodeQL sont indisponibles** — **c'est ATTENDU, pas un échec** : ils arrivent au flip *(§4)*.
- ⚠️ **La description ne doit contenir aucun caractère de contrôle** *(l'API renvoie 422)* — le script les retire et le signale. **Éviter aussi les tirets cadratins collés d'un copier-coller.**
- 💡 **`--dry-run`** : lit tout, **n'écrit rien**. À utiliser sur un repo **vivant** dont on n'est pas sûr.

### 🔴🔴 Étape 7c — Romain : **RÉVOQUER LE PAT ADMIN. MAINTENANT.**

**→ https://github.com/settings/personal-access-tokens**

> **C'est l'étape qu'on oublie, et c'est la plus dangereuse à oublier.**
> Ce token peut **supprimer le repo** et **changer sa visibilité** — il n'a **plus aucune raison d'exister** dès que le script a fini. *(Pourquoi révoquer plutôt que dégrader → §7 en bas.)*
>
> *(Le script le rappelle en fin de course — **un rappel n'est pas une révocation**.)*

### Étape 8 — Romain : installer Renovate

**→ https://github.com/apps/renovate** — *« Install » → Only select repositories → ce repo.*

> **Sans elle, `renovate.json` est INERTE** : les 4 binaires épinglés *(gitleaks, actionlint, osv-scanner, trivy)* **gèlent en silence** *(pourquoi ça compte : §17)*.

> 🔴 **L'ORDRE EST UN PIÈGE — `renovate.json` DOIT être sur `main` AVANT que l'app ne soit installée.**
> Renovate regarde s'il trouve une config sur la branche par défaut.
> **Il en trouve une → il se met au travail directement.**
> **Il n'en trouve pas → il ouvre une PR d'onboarding « Configure Renovate ».**
>
> Ici, l'ordre est bon **par construction** : le template pose `.github/renovate.json` dès l'étape 1, donc à l'étape 8 le fichier est déjà sur `main` — **aucune PR d'onboarding n'apparaît**.
>
> **⚠️ Sur un repo EXISTANT** *(mise en conformité, §7)*, **l'ordre s'inverse tout seul** : l'app est souvent installée avant que le fichier n'arrive → **la PR d'onboarding surgit**.
> **NE JAMAIS LA MERGER** *(la merger activerait la config **par DÉFAUT** de Renovate, pas la `renovate.json` **accordée** du template)*.
> **Conduite à tenir : FERMER la PR d'onboarding** *(Renovate s'arrête, et il ne la rouvre pas)*, **puis commiter `.github/renovate.json`** — Renovate redémarre de lui-même dès qu'il voit le fichier. Le geste est **réversible dans les deux sens**.

### Étape 9 — Romain, **si le repo a un arbre npm** : activer Dependabot malware alerts (UI)

> **npm-only · AUCUNE API → `configure-repo.sh` NE PEUT PAS le poser** *(cf. §7)*. Disponible **dès le privé Free** *(pas gaté par le plan)*.
> **→ Settings → Advanced Security → *Dependabot malware alerts* → Enable.**
> Détecte les versions npm **malveillantes** *(paquet compromis, typosquat)* — un angle que **Renovate ne couvre pas** : Renovate remédie aux **CVE** par montée de version, or un paquet malveillant n'a souvent **aucune version saine** où bumper. **Inutile sur un repo sans `package.json`.**

---

## 2 · Travailler au quotidien

**`main` est la production. On n'y écrit jamais directement.** *(standard §12)*

```bash
git switch -c feat/<sujet>          # depuis `develop` si --staging, sinon depuis `main`
git commit                          # le hook pre-commit REFUSE un secret
git push -u origin feat/<sujet>     # le hook pre-push REFUSE main/develop
gh pr create --fill

# La CI est-elle verte ? (voir l'avertissement ci-dessous — PAS `gh pr checks`)
sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
gh run list --commit "$sha"

gh pr merge --squash                # SEULEMENT si tous les workflows attendus sont completed/success
```

> 🔴 **En PRIVÉ, rien n'exige la CI.** Aucun ruleset → GitHub **accepterait** le merge d'une PR rouge. Vérifier la CI avant tout merge est le **seul point resté humain** de toute la chaîne : aucun hook ne peut l'intercepter, le merge se joue côté serveur.
>
> **VERT ⇔ TOUS les workflows ATTENDUS sont `completed / success`** : `CI`, **+ `Publish image`** si `docker-publish.yml` existe *(le même ensemble que les checks requis du ruleset — `configure-repo.sh` le dérive de la présence du workflow)*.
> ⚠️ **Un workflow ABSENT de la liste n'est PAS un vert** : il n'a simplement pas encore rapporté. GitHub enregistre les workflows **un par un** après un push — pendant quelques secondes, `CI` peut être `success` alors que `Publish image` n'existe pas encore. *« Rien de rouge » et « tout est vert » ne sont pas la même affirmation*, et l'écart entre les deux est exactement là où un change cassé passe.

> 🔴 **Ne PAS utiliser `gh pr checks <n>`** *(ni `gh pr view <n>` tout court)* : les deux lisent `statusCheckRollup`, qui exige la permission **`Checks`** — **absente de l'UI des PAT fine-grained**, impossible à accorder *(github/community#129512, cli/cli#12597)*. Avec le PAT du standard, la commande renvoie **`Resource not accessible by personal access token`**.
> **Rien à ajouter au PAT** : la commande ci-dessus n'a besoin que d'`Actions: read`, déjà dans la matrice. *(`gh pr view --json headRefOid` passe : en ciblant un champ, il ne demande plus le rollup.)*

**Avec `--staging`** : les `feat/` s'accumulent dans `develop`. `develop → main` n'arrive **qu'au moment de publier une version** — **une seule PR pour N changements**, pas deux PR par changement.

---

## 3 · Publier une version

| # | Qui | Geste |
|---|---|---|
| 1 | Claude | `CHANGELOG.md` : passer `Unreleased` en `X.Y.Z` *(ce que la release raconte à l'utilisateur ; les notes GitHub listent les PR — les deux sont complémentaires)*. |
| 2 | Claude | *(si `--staging`)* PR `develop → main`, CI verte, merge **en merge commit** *(jamais squash — §12)*. ⚠️ **PUIS : voir l'encadré ci-dessous — ce merge SUPPRIME `develop` tant que le repo est privé.** |
| 3 | Claude | `git tag vX.Y.Z && git push origin vX.Y.Z` → la **Release** est créée, et l'**image ghcr** poussée *(si `--artefact`)*. ⚠️ **Avec `--artefact`, la Release est le job `release` de `docker-publish.yml`** *(`needs: build-push` — pas de Release si l'image n'a pas été publiée)* ; **sans** cette capacité, c'est `release.yml`. **Un seul des deux existe**, jamais les deux. |
| 4 | **Romain** | ⚠️ **1ʳᵉ release — VÉRIFIER que le package ghcr est tirable, et n'agir QUE s'il ne l'est pas.** Sur un compte **PERSO**, un package publié depuis un repo **public** hérite de son accès : il est tirable **aussitôt**, aucun geste. Sur une **ORG**, il peut être **PRIVÉ** *(défaut d'org)* → `docker pull` anonyme = **403**, et **personne ne peut auto-héberger**. **`configure-repo.sh` fait le test lui-même** et ne réclame le geste que s'il échoue. |
| 5 | Claude | Vérifier que l'image est **réellement tirable** — `configure-repo.sh` le teste **anonymement**, comme le fait le host de prod. ⚠️ **Un job « Publish image » VERT ne prouve RIEN** : il peut réussir alors que l'image reste **intirable** (package privé). |

> 🔴 **LA MISE EN PRODUCTION DÉTRUISAIT LE STAGING — tant que le repo est PRIVÉ.**
> ✅ **Corrigé à la racine** : sur un repo **privé** qui publie un flux à 3 étages, `configure-repo.sh` **RETIRE** `delete-branch-on-merge`. On perd le nettoyage automatique des `feat/*` *(un clic)* ; on garde la branche de staging. Le flip en public le **rétablit** *(rejouer le script — le ruleset prend le relais)*.
> ⚠️ **Un repo configuré AVANT ce correctif porte encore le réglage** : rejouer `configure-repo.sh` avant sa prochaine promotion, sinon ce qui suit s'applique toujours.
> `delete-branch-on-merge` supprime la branche **source** de **toute** PR mergée — donc **`develop` elle-même**, au merge de la PR `develop → main`.
> **En PUBLIC**, le ruleset `develop` (règle `deletion`) **l'en empêche**. **En PRIVÉ, il n'existe aucun ruleset : la branche est supprimée, sans un mot.**
> **Le dégât est en cascade** : au rejeu suivant, `configure-repo.sh` ne voit plus `develop`, en conclut « pas de staging », **ne pose pas son ruleset** et **repasse `main` en squash-only** → **la promotion suivante devient IMPOSSIBLE** *(squasher `develop` dans `main` fait diverger les deux branches à chaque cycle — §12)*.
> **→ Après une promotion sur un repo PRIVÉ, RECRÉER `develop` immédiatement :**
> ```bash
> git switch -c develop main && git push -u origin develop
> ```
> *(Le script le détecte et le signale : il compare le bloc `## Branching` de `CONTRIBUTING.md` à ce qui **existe** réellement.)*

> ⚠️ **Les immutable releases ne sont PAS rétroactives.** Elles doivent être posées **avant la v1** — après, il est trop tard pour les releases déjà publiées.
> `configure-repo.sh` s'en charge **dès le privé** *(le réglage y est disponible)* : rien à attendre, et un repo qui ne bascule jamais en public est couvert lui aussi.

---

## 4 · Basculer PRIVÉ → PUBLIC

> 🔴 **Le moment le plus dangereux du cycle de vie.** **Tout l'historique devient public d'un coup** — y compris un secret enfoui dans un commit de six mois, poussé pendant la phase où **aucun secret scanning serveur n'existait**. D'où l'étape 1, non négociable.

| # | Qui | Geste |
|---|---|---|
| 1 | Claude | **`gitleaks` sur TOUTES les refs**, pas seulement `main` — un secret dans une vieille branche poussée devient public lui aussi. |
| 2 | Claude | Vérifier qu'**aucun `<placeholder>` ne subsiste** dans les fichiers versionnés — surtout `<contact>` dans `SECURITY.md`. |
| 3 | **Romain** | Flipper la visibilité *(UI)*. |
| 4 | **Romain** | **Rejouer `configure-repo.sh`** *(PAT admin éphémère)* → rulesets `main`/`develop`/`tags`, secret scanning + push protection, **private vulnerability reporting**, **immutable releases**, Pages, description, topics, et **L'ACTIVATION DE CODEQL** *(default setup — il attend la 1ʳᵉ analyse, puis pose la règle `code_scanning`)*. **Le script est idempotent : c'est fait pour.** |
| 5 | **Romain** | **Repo d'ORG uniquement** — Settings → **Moderation options** → **Reported content** → « Prior contributors and collaborators ». **Aucune API.** Sans ce clic, le community health **plafonne à 87 %**. |
| 6 | — | **Rien à faire pour les workflows** : `pages.yml` porte `if: visibility != 'private'` — il est `skipped` en privé et **se réveille seul**. ⚠️ **CodeQL n'est PLUS un workflow** *(il n'y a plus de `codeql.yml`)* : il est activé **par le script**, à l'**étape 4**, en ***default setup*** — GitHub y détecte les langages et **les tient à jour tout seul** *(standard §17)*. |
| 7 | — | **Rien à faire pour la règle `code_scanning`** : à l'**étape 4**, le script **active CodeQL, ATTEND sa 1ʳᵉ analyse, PUIS pose la règle** — en **une seule** exécution *(sinon `main` resterait NON gardée jusqu'à un rejeu — conséquence détaillée §1 étape 7a)*. |
| 8 | Claude | Vérifier en lecture : community health **100 %** · CodeQL **vert** · rulesets **actifs** · secret scanning **on**. |

> **CodeQL analyse tout l'historique d'un coup** au flip — `semgrep` + `osv-scanner` tournent donc **depuis le premier jour** *(détail : §18)*.

---

## 5 · Faire évoluer un projet vivant

**On ne change pas d'archétype — on ACQUIERT une capacité.** *(standard §18, checklists détaillées)*

| Besoin | Capacité | ⚠️ Le piège |
|---|---|---|
| « je veux que d'autres puissent **auto-héberger** » | `--artefact` | **L'ORDRE.** Le workflow doit atteindre `main` **AVANT** que `configure-repo.sh` n'exige `build-check` — sinon **le repo se verrouille lui-même**, y compris contre la PR qui apporte le workflow. |
| « un **host** apparaît, je veux le valider » | `--staging` | Rejouer `configure-repo.sh` : il pose le ruleset `develop` **et autorise le merge commit** *(squash seul est incompatible avec une branche de staging)*. |
| « le site part **hors Pages** » | retirer `--pages` | Supprimer `pages.yml`. Ne **jamais** le laisser tourner « au cas où » — un workflow orphelin est un contrôle que plus personne ne lit. |
| **retirer** une capacité | — | ⚠️ Retirer `build-check` des checks **requis AVANT** de supprimer `docker-publish.yml`. Sinon le check reste exigé alors que plus rien ne le produit → **toute PR bloquée pour toujours**. |

---

## 6 · Maintenance courante

| Quoi | Qui | Quand |
|---|---|---|
| **PR Renovate** *(TOUT : écosystèmes auto-détectés — actions, npm, docker, pip… — **et** les 4 binaires épinglés VERSION+SHA256)* | Claude — **en autonomie** | hebdo. Minor/patch groupés, **majeures seules**. **Routine = PR revue par un humain ; SÉCURITÉ = auto-mergée** *(aucun geste)*. ⚠️ **Si le checksum d'un binaire est faux, `sha256sum -c` fait échouer la CI** — bruyamment. Une PR rouge se ferme. |
| **Alertes Dependabot** et **code scanning** | Claude — **en autonomie** *(dismiss/reopen)* | à réception |
| **Alertes SECRET SCANNING** | 🔴 **ROMAIN SEUL** | L'assistant est en **lecture seule** dessus *(pourquoi : §1 étape 3)*. |
| **Rotation du PAT d'écriture** | Claude **alerte à J-14** · **Romain régénère** | tous les **90 j** |
| **`SUIVI.md`** | Claude — **de lui-même** | consolider · purger le livré |

---

## 7 · Les gestes que Claude ne peut PAS faire

*(Ce ne sont pas des oublis : c'est le modèle de sécurité — §5, `github-repo-config.md` §2.)*

- **Créer** ou **supprimer** un repo · **changer la visibilité** → droit à portée de **compte**.
- **Tout ce qui exige `Administration`** : rulesets, secret scanning, Pages, immutable releases, description, **topics** → **PAT admin éphémère, joué par Romain**. ⚠️ **Ce sont des gestes du SCRIPT, pas des gestes « à la main »** : `configure-repo.sh` les pose tous *(topics inclus : `PUT /repos/{o}/{r}/topics` exige `administration=write`)*.
- **Rendre un package ghcr public** → **UI, aucune API** *(les PAT fine-grained ne couvrent pas ghcr — seuls les PAT `classic` le font)*. Le script **le TESTE** *(pull anonyme réel)* et **ne le réclame que si le test échoue** *(détail : §3 étape 4)*.
- **Reported content** → UI, aucune API.
- **Activer Dependabot malware alerts** *(repos npm)* → **UI, aucune API** — npm-only, dispo dès le privé Free *(détail : §1 étape 9)*.
- **2FA** → **UI, aucune API.** ✅ **DÉJÀ ACTIF sur le compte de Romain.** Réglage de **COMPTE**, **une fois pour toutes** — **pas** un geste par repo. ⚠️ **Ne pas le confondre avec le 2FA OBLIGATOIRE d'une ORG**, qui est un réglage **distinct** *(imposer le 2FA aux membres)* — voir l'encart ci-dessous.
- **Dismiss une alerte secret scanning** → **Romain seul.**

> ### Si le repo vit dans une ORGANISATION — 4 réglages, une seule fois par org
> **Aucun n'est scriptable sans un PAT `Organization Administration`** *(permission sans granularité : qui peut lire peut tout écrire)* — donc **UI, geste de Romain**.
> ✅ **Déjà posés sur `bayalis` et `quatrecarre`** *(25/07)* — c'est l'**état attendu** de toute org :
>
> | Réglage | Où | Valeur |
> |---|---|---|
> | **2FA obligatoire** | `/settings/security` | activé |
> | **PAT classiques** | `/settings/personal-access-tokens?tab=classic` | **Restrict** *(bloqués)* |
> | **PAT fine-grained** | `/settings/personal-access-tokens` | approbation admin **requise** + durée de vie max **90 j** |
> | **Visibilité par défaut des packages** | `/settings/packages` | ⚠️ sur une **org**, un package ghcr est **privé d'office** *(§3 étape 4)* |
>
> ⛔ **Ce que l'org n'apporte PAS, malgré les apparences** : les **rulesets d'org** exigent **Team** *(bandeau explicite sur `/settings/rules`)* · une **code security configuration** ne remplace le geste repo qu'à partir de **plusieurs** repos *(en dessous, `configure-repo.sh` fait déjà tout)* · l'écran **« Advanced Security »** laisse croire que **Dependabot** est derrière le mur payant : **c'est faux**, il est gratuit, privé compris — c'est `/settings/security_analysis` qui dit vrai.

> **Pourquoi le PAT admin est JETABLE plutôt que dégradé après coup** → `github-repo-config.md` §2. *(En un mot : **révoquer est binaire ; dégrader des droits ne l'est pas** — et un retrait manuel est oubliable.)*
