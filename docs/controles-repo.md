# Contrôles d'un repo — du commit à la production

> Référence. Complète `claude-code-project-standard.md` §18.
> **La colonne « Privé » est la clé** : un repo privé en plan Free n'a **aucun ruleset**.
> Les contrôles tournent, mais **rien ne les exige** — une PR rouge peut être mergée.

## Le flux — où va le code

**Le principe unique : `main` est la production.**
On n'y écrit **jamais** directement — la seule porte d'entrée est une **pull request dont la CI est verte**.
Tout le reste en découle.

> ### Ce qui décide du flux : *une seule question*
> **« Existe-t-il un host à VALIDER avant la production ? »** — c'est la capacité **`staging`**, et elle seule.
> **Pas le langage, pas Docker.**
> Un projet `node` sans host à valider n'a **pas** besoin de `develop`. Une page Pages qu'on package en image **non plus** — l'image *est* la page.
> La publication d'un **artefact** (tag → image ghcr) est une capacité **indépendante** : elle se greffe sur **les deux** flux ci-dessous.

### Sans `staging` — GitHub Flow, deux branches suffisent

Le cas d'un site Pages, **et aussi** celui de `rozo-bridge` packagé en image pour que des tiers l'auto-hébergent.
Rien à valider en amont → une `develop` serait un **rituel vide**, et une branche longue que personne n'utilise dérive jusqu'à ce que le merge cesse d'avoir lieu.

```
main     ●──────────────────●──────────────●────◆
                            ▲               │    └─ tag v* → image ghcr   (capacité `artefact`)
                       PR · CI verte        └────── merge → Pages = PROD  (capacité `pages`)
                            │
feat/…   ●────●────●────────┘
         commits (hook gitleaks à chacun)
```

> Les deux sorties sont **optionnelles et indépendantes** : un repo peut n'avoir que Pages, que l'image, ou **les deux** (c'est le cas de `rozo-bridge` une fois dockerisé).

| # | Étape | Commande |
|---|---|---|
| 1 | Brancher depuis `main` | `git switch -c feat/sujet` |
| 2 | Commiter — le hook refuse un secret | `git commit` |
| 3 | Ouvrir la PR — **la CI tourne avant que le code touche `main`** | `gh pr create --fill` |
| 4 | Merger **seulement si la CI est verte** | `gh run list --commit "$(gh pr view <n> --json headRefOid --jq .headRefOid)"` puis `gh pr merge --squash` *(**pas** `gh pr checks` : permission `Checks` non accordable — standard §18)* |

### Avec `staging` — trois étages, parce qu'il y a un host à valider

`develop` gagne sa place : il existe un **vrai host** (le NUC) à valider avant la production.
Et la prod ne suit pas une *branche*, elle suit un **tag épinglé** — on promeut un **artefact**, pas une branche.

```
main     ●───────────────────────────●────◆   tag v1.2.3 → image ghcr → PROD
                                     ▲
                                PR · CI verte  (release)
                                     │
develop  ●────●────●────●────────────┘   staging — déployé sur le NUC, validé
              ▲
         PR · CI verte
              │
feat/…   ●────┘
```

> ### Ce n'est PAS deux pull requests par changement
> C'est la confusion classique, et elle rendrait le flux insupportable.
> **Les `feat/` s'accumulent dans `develop`** — une PR chacune, c'est le rythme normal du travail.
> `develop → main` n'arrive **qu'au moment de publier une version** : **une seule PR pour N changements**.
> En solo, c'est de l'ordre d'une fois par semaine, pas une fois par commit.

> ### Pourquoi la pull request même seul, même en privé
> Sans PR, on pousse sur `main` et la CI tourne **après** : elle devient une **autopsie**, pas un barrage.
> Elle constate les dégâts sur la branche que l'on vient de déclarer « production ».
> Avec une PR, elle tourne **avant** — c'est toute la différence entre **savoir** et **empêcher**.
> *(L'incident qui l'illustre : standard §12.)*

> ### Là où l'on ne serre PAS la vis — *trop de contrôles tue le contrôle*
> - **Aucun lint au pre-commit** — aucun linter n'est universel aux deux toolchains ; en imposer un ferait échouer le hook dès le premier commit.
> - **Un seul contrôle bloquant en local : les secrets.** Vital, instantané, et **irréversible une fois poussé** — les trois critères qui justifient de bloquer. Le reste attend la CI, où l'attente ne coûte rien.
> - **Zéro relecture obligatoire** (`required_approving_review_count = 0`) : en solo, s'auto-approuver serait un théâtre.

---

## Les contrôles — ce qui vérifie le code

### Poste de développement

| Où / quand | Quoi | Avec quoi | Comment | Privé |
|---|---|---|---|---|
| Commit | Aucun secret dans les fichiers stagés | `gitleaks` | hook `.githooks/pre-commit` | ✅ |
| Push | Pas de push direct sur `main`/`develop` | hook `pre-push` | hook `.githooks/pre-push` — *le substitut du ruleset absent* | ✅ |

### Intégration continue — job `checks` (`ci.yml`)

| Où / quand | Quoi | Avec quoi | Comment | Privé |
|---|---|---|---|---|
| Pull request | Secrets sur l'historique **complet** | `gitleaks` | binaire épinglé + checksum | ✅ |
| Pull request | Failles du **code applicatif** | `semgrep` | `p/security-audit`, `p/owasp-top-ten`, `--exclude=.github` | ✅ |
| Pull request | Dépendances vulnérables (lockfile) | `osv-scanner` | binaire épinglé + checksum | ✅ |
| Pull request | Workflows : syntaxe + shell | `actionlint` | binaire épinglé + checksum | ✅ |
| Pull request | Workflows : injection `${{ }}`, pinning | `zizmor` | config `.github/zizmor.yml` | ✅ |
| Pull request | Tests · types · audit npm | `npm test` · `npm run typecheck` · `npm audit` | toolchain `node` | ✅ |
| Pull request | Syntaxe de tous les JS | `node --check` | toolchain `static` | ✅ |
| Pull request | Dépendance entrante + **licences** | `dependency-review` | conditionné au public (exige GHAS) | ❌ |

### Intégration continue — autres jobs

| Où / quand | Quoi | Avec quoi | Comment | Privé |
|---|---|---|---|---|
| Pull request | CVE de l'image Docker (CRITICAL/HIGH) | `trivy` | job `build-check` — **check requis** | ✅ |
| PR + push | Analyse statique **inter-fichiers** | `CodeQL` | **default setup** (activé par `configure-repo.sh`) — public seulement | ❌ |
| Repo **sans CI** | Secrets (historique complet) | `gitleaks` | `gitleaks.yml` autonome — PR + hebdo | ✅ |

### Serveur — posé par `configure-repo.sh`

| Où / quand | Quoi | Avec quoi | Comment | Privé |
|---|---|---|---|---|
| Merge | PR obligatoire · checks **requis** · pas de force-push | rulesets `main` / `develop` | indisponible en privé (Free) | ❌ |
| Tag | Tag `v*` ni déplaçable ni supprimable | ruleset `tags` | sans lui, le pin de prod ne vaut rien | ❌ |
| Release | Assets non remplaçables | immutable releases | `PUT /immutable-releases` — **non rétroactif** | ❌ |
| Push serveur | Secret dans le push | secret scanning + push protection | natif GitHub | ❌ |
| Après release | **L'image est-elle tirable ?** | `curl ghcr.io/v2/…/manifests` | test **anonyme**, comme le host de prod | ❌ |

### Publication & veille

| Où / quand | Quoi | Avec quoi | Comment | Privé |
|---|---|---|---|---|
| Push tag `v*` | Publication de l'image sur ghcr | `docker-publish.yml` › `build-push` | déclenché par le tag | ✅ |
| Hebdomadaire | Mises à jour de toutes les dépendances (npm · docker · actions · pip…) | Renovate | `renovate.json` — auto-détecté, minor/patch groupés | ✅ |
| Continu | CVE des dépendances (**détection**) | Dependabot alerts | natif — gratuit même en privé ; Renovate **lit** ces alertes et ouvre la PR de fix (**réparation**) | ✅ |

---

## La bascule privé → public

Le cycle nominal : le repo **naît privé**, il **devient public**.
Tout ce qui dormait s'active **d'un seul coup** — c'est le moment le plus dangereux de sa vie.

| Pendant le privé — *tout tourne, rien n'est exigé* | Au passage en public — *le serveur applique ce que la discipline retenait* |
|---|---|
| ✅ gitleaks (hook + CI, historique complet) | ✅ Rulesets `main`, `develop`, `tags` |
| ✅ hook `pre-push` : pas d'écriture directe sur `main` | ✅ Checks **requis** avant merge |
| ✅ semgrep · osv-scanner | ✅ Secret scanning + push protection |
| ✅ actionlint · zizmor · trivy | ✅ CodeQL — *analyse tout l'historique d'un coup* |
| ✅ tests · typecheck · Renovate + Dependabot alerts | ✅ dependency-review · immutable releases |
| ❌ **Aucun ruleset** — une PR rouge peut être mergée | ✅ Private vulnerability reporting |


## Le trou de la phase privée

En privé, GitHub n'exige **rien** : push direct sur `main` accepté, PR rouge mergeable. La discipline est donc **outillée** (hooks `pre-commit` / `pre-push`, contournables par `--no-verify` — une décision, pas un accident). **Un seul point reste humain** : ne jamais merger une PR rouge — vérifier via `gh run list --commit <sha-de-tête-de-la-PR>`, **jamais** `gh pr checks` (permission `Checks` inaccordable en fine-grained).

**Détail complet** (licence CodeQL en privé, rôle permanent de Semgrep/osv-scanner, définition du vert, piège du faux vert, commande exacte) : **standard §18, « Le trou de la phase privée »**.
