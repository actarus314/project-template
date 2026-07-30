# Configuration du repo GitHub — référence

> Complément **one-shot** du standard (`claude-code-project-standard.md` ; auth = §5).
> Ce qui se règle **une fois** à la création d'un repo, + le modèle de PAT.
> ⚠️ **Cycle nominal : repo créé PRIVÉ, puis passé PUBLIC.** `configure-repo.sh` se joue donc **deux fois** : à la création (il pose ce que le plan Free autorise) puis **au flip** (il pose le reste — rulesets, secret scanning, Pages). Il est **idempotent** : c'est fait pour.
> **Le modèle : une TOOLCHAIN + trois CAPACITÉS.** Un archétype rigide (« statique » vs « Node/Docker »)
> fusionnerait trois questions **indépendantes**, et casserait dès qu'on en sort — *une page hébergée
> hors Pages, ou une page Pages qu'on packagerait aussi en image pour des auto-hébergeurs*.
>
> | | Ce que ça décide | Valeurs |
> |---|---|---|
> | **Toolchain** (`--type`) | **uniquement** quel `ci.yml` | `static` (aucun npm) · `node` (npm, tests, types) |
> | **Capacité `pages`** | le site est servi par **GitHub Pages** | `pages.yml` |
> | **Capacité `artefact`** | le repo **publie une image que QUELQU'UN D'AUTRE déploie** | `docker-publish.yml` · Trivy · ruleset tags · immutable releases · package ghcr **public** |
> | **Capacité `staging`** | il existe un **host à VALIDER** avant la prod | branche `develop` · ruleset `develop` · flux 3 étages |
>
> 🔴 **`develop` découle du STAGING, jamais de Docker ni du langage.** Un projet `node` sans host à valider n'en a **pas**. `rozo-bridge` + image non plus. *(Standard §12.)*

## 1. Contrôles sécu & code — quoi activer, où

### Baseline — TOUT repo, sans exception
| Contrôle | Réglage | Quand |
|---|---|---|
| **`gitleaks`** | **hook `pre-commit`** (fichiers stagés) **+ CI sur l'historique COMPLET**. **Jamais optionnel** : c'est le **seul** filet anti-secret pendant toute la phase privée (aucun secret scanning serveur en Free). Binaire épinglé + checksum — **pas** `gitleaks-action`, qui exige une **licence** sur un repo d'ORG. | commit + chaque PR |
| **`semgrep`** | analyse statique du **code applicatif** (`p/security-audit`, `p/owasp-top-ten`, `--exclude=.github`). Existe parce que **CodeQL est indisponible en privé** — il le **précède**, ne le remplace pas (analyse fichier par fichier). | chaque PR |
| **`osv-scanner`** | dépendances vulnérables (tous manifestes, `-r .`, base OSV). **L'équivalent de `dependency-review` qui, lui, marche en privé.** | chaque PR |
| **`actionlint` + `zizmor`** | les workflows sont du code : un `${{ }}` dans un `run:` est une **injection shell**. | chaque PR |
| **CodeQL** | **default setup** natif, activé par `configure-repo.sh` (`PATCH /code-scanning/default-setup`, `Administration: write`). **Détecte les langages et les TIENT À JOUR tout seul** — notre ancien `codeql.yml` n'en déclarait qu'UN, et ratait les workflows `actions` (§17). **Indisponible en privé** (GHAS) → arrive au flip. Les deux modes sont **exclusifs**. | push/PR `main` + hebdo |
| **Dependabot alerts** | **détection de CVE** — natif, gratuit même en privé, **partout** : c'est le dependency graph que Renovate lit. Version updates → **Renovate**. Les **security updates**, elles, ne sont le filet **qu'à 2 étages** — à 3 étages leurs PR viseraient `main` et court-circuiteraient le staging *(→ standard, « Qui met à jour les dépendances »)*. | continu |
| **Renovate** | **seul bot d'update.** Auto-détecte **tous** les écosystèmes du repo (npm, docker, actions, pip…) **sans aucune déclaration**, + les 4 binaires épinglés VERSION+SHA256 (gitleaks, actionlint, osv-scanner, trivy). Lit les Dependabot alerts (`vulnerabilityAlerts`) pour ses PR sécu. Routine = PR revue par un **humain** ; **sécurité = auto-merge**. Minor/patch groupés. | continu / hebdo |
| **Secret scanning + push protection** | natif, gratuit en **public** (indisponible en privé/Free). | chaque push |
| **Ruleset `main`** | PR obligatoire · checks requis (**`checks`** + CodeQL + **`build-check` si capacité artefact**) · no force-push/delete · no bypass · `required_approving_review_count = 0` (solo). | continu |
| **Ruleset `tags` + immutable releases** | un tag `v*` ni déplaçable ni supprimable, des assets non remplaçables. **Sans les deux, le pin de prod du §13 ne vaut RIEN.** | continu |
| **Actions tierces** | **SHA complet** (`# vX.Y.Z` en commentaire) ; `actions/*` et `github/*` : tag majeur toléré. | — |
| **`permissions:` workflows** | minimal : `{}` deny-all + write scopé **par job** · `persist-credentials: false` sur tout `checkout`. | — |

### En plus — TOOLCHAIN `node`
| Contrôle | Réglage |
|---|---|
| `npm audit --audit-level=high --omit=dev` · `npm test` · `npm run typecheck` | gate PR. |

*(Les mises à jour npm **et** docker ne sont plus des lignes par toolchain : Renovate les auto-détecte — voir la ligne **Renovate** de la baseline.)*

### En plus — CAPACITÉ `artefact` *(⚠️ PAS « node » : `rozo-bridge` est `static` et publie une image)*
| Contrôle | Réglage |
|---|---|
| **Trivy en gate PR** | job **`build-check`** de `docker-publish.yml` : build (`load: true`) puis `trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1`. **Binaire épinglé + checksum.** `configure-repo.sh` en fait un **check REQUIS** — *un scan non exigé ne bloque rien.* |
| **Durcissement Docker** | base image pin par **digest** SHA256 · runtime **sans gestionnaire de paquets** (§14) · `tmpfs` `noexec,nosuid,nodev,size=` · healthcheck · `:latest` bloqué sur pré-release. |
| **Package ghcr PUBLIC** | 🔴 Défaut dépend du **propriétaire** : compte **perso** → tirable anonymement (**HTTP 200**) ; **organisation** → privé d'office (**403**), personne ne peut auto-héberger. `configure-repo.sh` **teste le pull anonyme** et ne réclame le geste que si le test échoue. **Détail, provenance des tests, procédure UI : §4 « Visibilité du package ghcr ».** |

### En plus — CAPACITÉ `staging`
| Contrôle | Réglage |
|---|---|
| **Ruleset `develop`** | les exigences de `main`, **moins deux, à dessein** : ❌ pas de `code_scanning` *(CodeQL n'analyse que `main` — l'exiger ici bloquerait toute PR sur un check qui n'arrivera jamais)* · ❌ **squash SEUL** *(le merge commit est réservé à `main`, pour les promotions)*. |
| **Merge commit autorisé sur `main`** | squash seul est **incompatible** avec une branche de staging. |

> **Note plan** : sur compte perso (non-org), le secret scanning public n'a que les **patterns par défaut** — pas de regex custom ni validity checks (réservés à GitHub Secret Protection, payant/org). D'où l'intérêt de gitleaks pour des secrets non standards.

## 2. Permissions PAT — deux étages

> 🎯 **Pour EXÉCUTER** (créer le token, cocher les cases) → **`RUNBOOK.md` §1**, qui porte les tables
> prêtes à l'emploi et **fait foi**. **Cette section-ci explique POURQUOI** chaque permission est là :
> elle est **dérivée des endpoints appelés**, jamais découverte par essais successifs.
> **Ne jamais la découvrir par tâtonnement** : chaque permission manquante
> **échoue en SILENCE** — tout le reste passe, et le contrôle absent ne se voit pas.

Miroir du one-shot/récurrent : **l'assistant gère tout le récurrent en autonomie ; l'admin one-shot reste manuel (Romain)**.

| RÉCURRENT → PAT assistant (fine-grained, 1 repo) | ONE-SHOT → Romain (Administration: write) |
|---|---|
| Contents: **write** | Activer les features sécu (secret scanning, push protection ; **Dependabot alerts ON** partout, **security updates ON à 2 étages seulement** ; Renovate ajoute l'auto-merge sécu) |
| Pull requests: **write** | Créer/éditer rulesets & branch protection |
| Issues: **write** | `PATCH /repos` : visibilité, merge-methods, delete-branch, topics, homepage |
| Actions: **read/write** (relancer/annuler runs) | Activer **CodeQL default setup** *(`configure-repo.sh` le fait)* |
| Dependabot alerts: **write** (dismiss/reopen) | Dependabot **secrets** (valeurs), webhooks, deploy keys |
| Code scanning alerts: **write** (dismiss) | 2FA (réglage de **compte**, pas de repo — UI/mobile only) |
| **Secret scanning alerts: read** — dismiss réservé à Romain (rejeter à tort une vraie fuite = trop d'impact) | |
| **Administration: read** *(JAMAIS write)* — **VÉRIFIER** ce qu'un `✓` affirme : `GET /automated-security-fixes` · `GET /vulnerability-alerts` · `GET /branches/{b}/protection` | |
| Metadata: read (implicite) · **Workflows: write** — l'assistant édite les YAML de CI | |

**Vérifié** : traiter (dismiss/reopen) une alerte Dependabot ou code scanning ne demande **que** la permission dédiée en *write* — **aucune Administration**. Ouvrir une PR = Contents + Pull requests write ; merger = Contents write.
Le PAT garde les **permissions homogènes** du standard §5 (`Metadata R`, `Contents R/W`, `PR R/W`, `Issues R/W`, `Workflows R/W`, `Actions R/W`) **+** les 3 alertes ci-dessus **+ `Administration: read`**. **`Administration: write` : jamais.**

#### `Administration: read` — pourquoi une permission de plus, et pourquoi celle-là

**Elle ne mute rien.** Ce qui rend `Administration` redoutable *(supprimer le repo, flipper la visibilité, réécrire un ruleset)* est dans le **write**, réservé au PAT admin éphémère.

Elle ferme un trou de **vérification**, dérivé de trois endpoints qu'aucune autre permission n'ouvre :

| Lire | Sinon |
|---|---|
| `GET /automated-security-fixes` · `GET /vulnerability-alerts` | l'état des toggles sécu n'est **pas lisible** : le seul contrôle est une capture d'écran de Romain |
| `GET /branches/{b}/protection` *(+ `/required_status_checks`)* | la protection **CLASSIQUE** reste invisible — l'API `rulesets` ne la montre pas, et elle peut verrouiller `main` **pour toujours** |

🔴 **Le motif de fond : un `✓` affiché par un script n'est pas un réglage appliqué.** Un `--dry-run` a déjà annoncé 3 réglages dont **2 étaient impossibles**, et une protection classique a déjà bloqué toute PR sur un repo, CI verte. Sans lecture, ces deux pannes sont **structurellement indétectables** par l'assistant — c'est la maintenance sécu en autonomie qui retombe sur Romain.

> 🔴 **`Checks` n'est PAS dans cette liste — et ne peut PAS y être.** Documentée par GitHub, **absente de l'UI** des PAT fine-grained → `gh pr checks` et `gh pr view` échouent (ils lisent `statusCheckRollup`). Vérifier la CI verte via `gh run list --commit <sha>` (`Actions: read`, déjà là) à la place. **Détail, citations, commande exacte, piège du faux vert : standard §18.**

> **Admin one-shot — token ÉPHÉMÈRE, aucun token dormant**
>
> Le PAT Administration ne vit **nulle part** : ni keychain, ni `.envrc`, ni historique shell.
> **Créé → utilisé → révoqué**, en quelques minutes. `configure-repo.sh` le demande en **saisie masquée**.
>
> - Fine-grained · **« Only select repositories » = CE repo** → blast radius **1 repo**. Recette **complète**, une permission par endpoint appelé *(vérifiée sur la doc REST « Permissions required for fine-grained PATs » — la déduire des endpoints, ne JAMAIS la découvrir par essais successifs)* :
>
>   | Permission | Niveau | Pourquoi |
>   |---|---|---|
>   | **Administration** | **write** | `PATCH /repos` (merge, description, homepage) · `PUT /vulnerability-alerts` · `*/rulesets` · `PUT /immutable-releases` *(même permission — rien à ajouter à la recette)* |
>   | **Pages** | **write** | `POST`/`PUT /pages` — création du site, source = workflow |
>   | **Code scanning alerts** | **read** | `GET /code-scanning/analyses` — savoir si CodeQL a tourné |
>   | **Actions** | **read** | 🔴 `GET /actions/runs/{id}` — **suivre le run de la 1ʳᵉ analyse CodeQL**. Sans lui, le script ignore quand elle se termine → il **ne pose pas la règle `code_scanning`**, et **`main` reste NON gardée**. |
>   | **Contents** | **read** | `GET /contents/…` — détecter `pages.yml` (repo privé) |
>   | **Metadata** | read | implicite |
>
>   ⚠ **`Administration` NE SUFFIT PAS**, et **chaque permission manquante échoue en SILENCE** : tout le reste passe, et le contrôle absent ne se voit pas.
>   ⚠ Le `enablement: true` de `actions/configure-pages` **ne compense pas** l'absence de `Pages: write` : le `GITHUB_TOKEN` d'un workflow n'a pas ce droit → la création du site Pages échoue à **chaque** déploiement.
> - Suffisant : **tous** les appels du script sont **repo-level** (`PATCH /repos/{o}/{r}`, `PUT …/vulnerability-alerts`, `POST …/rulesets`). Aucun droit à l'échelle du compte n'est requis.
> - La **création du repo**, elle, exige un droit à portée du compte : elle se fait donc **dans l'UI** (30 s, quelques fois par an) — ce qui supprime purement le besoin d'un token large.
>
> **Pourquoi pas un PAT unique dont on retirerait `Administration` après coup** : cela donnerait à l'assistant, le temps de la config, le droit de **changer la visibilité** ou de **supprimer le repo** — et le retrait de permission serait **manuel, donc oubliable**, laissant un token vivant 90 j. Révoquer un token jetable est **binaire** ; dégrader ses droits ne l'est pas.
>
> **L'assistant n'a JAMAIS Administration.** `configure-repo.sh` est lancé par Romain.

## 3. OpenSSF Scorecard — garder / jeter (solo, public, petit)

- **Garder** (coût ~nul) : Token-Permissions · Branch-Protection · Pinned-Dependencies · Dangerous-Workflow (pas de `pull_request_target` + checkout de PR) · Security-Policy (`SECURITY.md`) · SAST (CodeQL) · Dependency-Update-Tool (Renovate).
- **Jeter** (overkill solo) : Signed-Releases · Fuzzing · CII-Best-Practices badge · signed commits (friction sans gain contre soi-même).
- **2FA** : oui, non négociable — mais réglage de **compte**, à activer en UI.

## 4. Mise en place — scriptable vs UI (pour `configure-repo.sh`)

> 🔴 **La VISIBILITÉ décide plus que le plan.** Cinq contrôles sont **impossibles** sur un repo **privé** — et **pas achetables** : il faut d'abord passer l'org en Team, *puis* acheter le produit. Sur un repo **public**, ils sont **gratuits**, même en Free.
>
> | Au FLIP public seulement | Dès la CRÉATION, privé compris |
> |---|---|
> | secret scanning · push protection · CodeQL · **rulesets** · PVR *(gate de VISIBILITÉ, pas de plan)* | cœur repo · merge · `GITHUB_TOKEN=read` · Dependabot alerts + security updates · **immutable releases** · fork-PR · rétention |
>
> ➡️ **Conséquence pratique** : rendre un repo public est une décision de **sécurité**, pas seulement d'ouverture. Et `configure-repo.sh` **lit `visibility`** pour appliquer cette partition — il est donc **fait pour être rejoué au flip**.
>
> ⚠️ **Ne jamais lire un champ absent comme « désactivé »** : sans `Administration`, `security_and_analysis` n'erreure pas — la clé est **omise**. « Vide » ≠ « off ».

| Réglage | Comment |
|---|---|
| **Immutable releases** | `gh api -X PUT repos/{o}/{r}/immutable-releases` (`Administration: write` — **déjà** dans la recette du PAT admin). 🔴 **NON RÉTROACTIF** → posé **dès le privé** *(le réglage y est disponible)*, jamais reporté au flip : ce qui n'est pas couvert à la publication d'une release ne le sera **jamais**. |
| **Private vulnerability reporting** | `gh api -X PUT repos/{o}/{r}/private-vulnerability-reporting` — **public-only** *(sans objet en privé : aucun chercheur externe n'y accède)*. |
| **`sha_pinning_required`** *(« Require actions to be pinned to a full-length commit SHA »)* | `PUT /repos/{o}/{r}/actions/permissions` — scriptable, dispo privé Free. ⏸️ **Délibérément NON posé** : le toggle natif est **plus strict que notre convention**, qui tolère le tag majeur pour `actions/*` et `github/*`. L'activer forcerait tout en SHA complet, first-party compris. *(zizmor couvre déjà le tiers.)* |
| **Dependabot malware alerts** | ⚠️ **UI, aucune API** *(ni champ `security_and_analysis`, ni endpoint)* — **npm-only**, dispo dès le privé Free. Détecte le paquet **malveillant**, angle que Renovate ne couvre pas *(il remédie aux CVE par montée de version ; un paquet malveillant n'a souvent aucune version saine)*. → geste de Romain, RUNBOOK §1 étape 9. |
| CodeQL | **`PATCH /repos/{o}/{r}/code-scanning/default-setup`** (`Administration: write`) — **scriptable, et DANS `configure-repo.sh`** |
| Dependabot alerts | `gh api -X PUT repos/{o}/{r}/vulnerability-alerts` |
| Secret scanning / push protection | `gh api -X PATCH repos/{o}/{r} -f security_and_analysis[...][status]=enabled` |
| **Dependabot security updates** *(le filet — **2 étages seulement** : à 3 étages, `DELETE` sur le même endpoint, cf. §« Qui met à jour les dépendances » du standard)* | `gh api -X PUT repos/{o}/{r}/automated-security-fixes` — 🔴 **endpoint DÉDIÉ, PAS une sous-clé de `security_and_analysis`** : `dependabot_security_updates` est dans le schéma de **réponse** du GET, **pas** dans les body-params du PATCH. Le passer au PATCH **ne lève aucune erreur** — il est ignoré, **en silence**. |
| Rulesets | `gh api -X POST repos/{o}/{r}/rulesets --input ruleset.json` (`gh ruleset` = lecture seule) |
| Topics / homepage / merge-methods / delete-branch | `gh repo edit --add-topic … --homepage … --enable-squash-merge --delete-branch-on-merge` |
| Updates Renovate · gitleaks · npm audit · CI | **fichiers committés** (`.github/renovate.json`, `.github/workflows/*.yml`), pas d'API |
| 2FA | **UI-only** (pas d'endpoint) |
| **Lecture de l'API packages / ghcr** | ❌ **IMPOSSIBLE en fine-grained** — GitHub Packages n'est **pas supporté** par les PAT fine-grained (classic `read:packages` uniquement). N'essaie pas d'ajouter la permission : **elle n'existe pas**. → **Sans objet** : le bon test est le **pull ANONYME** du registre (`ghcr.io/token` + `/v2/<img>/manifests/<tag>` → **200 = tirable**), qui vérifie *exactement* ce que fait le host de prod, **sans aucun token**. Posé par `configure-repo.sh`. |
| **Visibilité du package ghcr** | ⚠️ **UI, aucune API** *(les PAT fine-grained ne couvrent PAS ghcr — seuls les PAT `classic` le font)*. 🔴 **Le défaut DÉPEND DU PROPRIÉTAIRE, et le confondre coûte cher :** sur un compte **PERSO**, un package publié depuis un repo **public** est tirable **anonymement, SANS AUCUN GESTE** *(HTTP 200 — vérifié sur test003)*. Sur une **ORGANISATION**, il est **PRIVÉ d'office** → `docker pull` anonyme = **403**, et **personne ne peut auto-héberger** *(vérifié sur test004)*. → **`configure-repo.sh` TESTE le pull anonyme** et ne réclame le geste **QUE si le test échoue**. *(Org-wide : Settings → Packages → Package creation → default visibility.)* **Quand le geste EST nécessaire** *(org)* : Package settings → Danger Zone → *Change visibility* → **Public**. Sans lui, ni le host de prod ni un utilisateur ne peuvent tirer l'image — et **le pin de version en production ne vaut plus rien** : il désigne une image que personne ne peut récupérer. |
| **Reported content** (modération) | **UI-only — AUCUNE API** (vérifié : aucun endpoint de modération n'existe). Chemin exact, portée (org uniquement) et compte d'items : **§5, point 6**. ⚠️ La case **ne se coche pas** sur « All users ». |

> **Dry-run d'abord** : sur compte perso, certaines sous-clés `security_and_analysis` (`advanced_security`, `code_security`) sont probablement no-op hors GHAS/org. Tester sur le repo cible avant de graver dans `configure-repo.sh`.

## 5. Checklist nouveau repo (créé privé → passé public)

0. **Choisir la toolchain et les capacités** — *les trois questions, dans cet ordre* :
   **(a)** le site est-il servi par **Pages** ? → `--pages` · **(b)** le repo **publie-t-il une image que quelqu'un d'AUTRE déploie** ? → `--artefact` · **(c)** existe-t-il un **host à VALIDER** avant la prod ? → `--staging`.
   Puis : `./init-project.sh <projet> <owner/repo> [--type static|node|generic] [--pages] [--artefact] [--staging]`.
   *Raccourcis : `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging` · `--type generic` ≡ aucune capacité (toute autre toolchain — contrôles-sécu seuls, build/test à remplir).*
1. Créer le repo — **PRIVÉ** (le cas nominal), remote en **URL nue**, PAT 1-repo dans `.envrc` (standard §5) — avec les **3 permissions d'alertes** du §2.
2. `configure-repo.sh` : rulesets (`main` · `develop` **si staging** · `tags`) · secret scanning + push protection · **Dependabot alerts + security updates** *(filet ; Renovate ajoute l'auto-merge sécu)* · **immutable releases** · topics · homepage · delete-branch-on-merge *(**retiré** si flux à 3 étages **sans** ruleset — en privé Free, il supprimerait `develop` à la 1ʳᵉ promotion)* · **méthode de merge selon la capacité `staging`** — squash seul, **+ merge commit si `develop` existe** *(squash seul est incompatible avec une branche de staging)*. *(**CodeQL y est** : le script active le **default setup**, attend la 1ʳᵉ analyse, puis pose la règle `code_scanning`. Il n'y a plus de `codeql.yml`.)*
3. Fichiers présents dès le 1er commit : `LICENSE` · `README` (double-cible, standard §15) · `SECURITY.md` (advisories privées) · `CONTRIBUTING.md` · `CODE_OF_CONDUCT.md` · `.github/` (CI, `renovate.json`, `ISSUE_TEMPLATE/` + `config.yml`, PR template) · `.gitattributes` si lib vendorée.
4. **Avant de passer public** : `gitleaks detect` sur l'**historique complet** (pas juste HEAD) — un secret dans un vieux commit fuite au flip de visibilité.
5. Activer **2FA** du compte (UI).
6. **Repos d'ORG uniquement** — *« Repository admins accept content reports »* : Settings → **Moderation options** → **Reported content** → **« Prior contributors and collaborators »** (UI, **aucune API**).
   ⚠️ **Cet item n'existe QUE sur les repos appartenant à une organisation** ([changelog GitHub, 2020](https://github.blog/changelog/2020-06-23-community-content-reports-included-in-community-profile/)) : la checklist d'un repo d'org compte **8 items**, celle d'un compte perso **7**.
   **Conséquence à ne pas manquer** : un repo perso à 100 % et un repo d'org à 87 % peuvent avoir **exactement les mêmes fichiers** — comparer leurs scores n'a aucun sens.

> **Licence** : MIT par défaut (`templates/repo/LICENSE`). AVANT de figer — contrôle : (1) aucune dépendance ni code vendoré sous copyleft (GPL/AGPL) imposant plus strict ; (2) le projet gagnerait-il à du copyleft (anti-réappropriation propriétaire ; service réseau → AGPL) ? ; (3) dans le doute, demander à Romain — puis renseigner année + titulaire.

> Sources : GitHub Docs (code scanning, Dependabot, secret scanning, REST repos/rulesets/alerts) · OpenSSF Scorecard `docs/checks.md`.
