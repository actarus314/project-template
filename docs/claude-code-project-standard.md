# Standard d'organisation — Projets Claude Code

> Référence perso. S'applique à tout nouveau projet développé avec Claude Code (via Claude Desktop ou CLI).
> Objectif : organisation simple, réplicable, backupable en un seul dossier, avec séparation nette entre ce qui va sur GitHub et ce qui reste privé.

---

## 1. Concepts de base

Trois choses à distinguer clairement :

| Terme | Définition | Localisation |
|---|---|---|
| **Dossier de travail** | Le répertoire physique contenant tout (code, notes, secrets, logs) | `~/Documents/Claude/<projet>/` |
| **Repo Git local** | L'historique Git stocké dans `.git/` + les fichiers trackés | Dans `<projet>/repo/.git/` |
| **Repo GitHub** | Miroir distant du repo local, poussé sur github.com | Serveur GitHub (`origin`) |

**Règle d'or** :
> Le repo GitHub ne contient **que ce qui est nécessaire pour cloner, builder et lancer l'application**. Tout le reste — notes, plans, réflexions, secrets, config de dev personnel — vit dans le dossier de travail, hors Git.

Le `.gitignore` est la frontière opérationnelle entre les deux.

**Règle de langue & ton** :
> Tout le contenu **versionné (envoyé sur GitHub)** est rédigé en **anglais** — code, **commentaires de code**, docs de `repo/`, `README.md`, `.env.example` — sauf contre-ordre explicite. **Exception** : le `README.md` du projet est en anglais (défaut) **et** en français. Les fichiers locaux/gitignorés (`workspace/`, `secrets.md`, `CLAUDE.md`) peuvent rester en français.
>
> 🔵 **CONTRE-ORDRE EXPLICITE — le template lui-même est EXEMPTÉ** *(décidé le 2026-07-15)*.
> `template/repo/` reste **en français**, docs **et** commentaires de code. C'est un **outillage personnel qui a vocation à le rester** : son repo GitHub est **privé**, il ne cherche pas de contributeur, et l'anglais n'y achèterait rien qu'une traduction à maintenir.
> **L'exemption s'arrête au template.** Tout projet qu'il **génère** applique la règle ci-dessus — c'est d'ailleurs pour ça que les gabarits de `templates/repo/` sont, eux, **en anglais**.
>
> **Ton** : jamais de **2ᵉ personne** (`you/your`, `vous/tu/ton`) dans le contenu versionné **ni dans l'UI de l'app** — écrire « the user / l'utilisateur » ou des tournures impersonnelles.

---

## 2. Arborescence standard

```
~/Documents/Claude/<projet>/              ← dossier de travail (backupé sur NAS)
│
├── repo/                                 ← racine Git, cwd de Claude Code
│   │
│   ├── .git/                             (historique Git local)
│   ├── .gitignore                        (frontière versionné/ignoré)
│   │
│   ├── .env                              ← IGNORÉ — variables de déploiement de l'app (clés API runtime)
│   ├── .env.example                      ← versionné — template sans valeurs (app uniquement, pas le PAT)
│   ├── .envrc                            ← IGNORÉ — direnv : PAT du repo (GITHUB_PAT) + charge .env ; expose GH_TOKEN
│   │
│   ├── .claude/                          ← IGNORÉ — config dev perso de Claude Code
│   │   └── settings.local.json
│   │
│   ├── CLAUDE.md                         ← IGNORÉ — instructions Claude Code (pointeurs, conventions)
│   ├── README.md                         ← versionné — install/run/structure pour humains
│   │
│   ├── backend/, frontend/, shared/      ← versionnés — code de l'app
│   ├── docker-compose.yaml               ← versionné — orchestration runtime
│   │
│   ├── data/                             ← IGNORÉ — données runtime (SQLite, caches)
│   ├── node_modules/                     ← IGNORÉ — dépendances installées
│   └── dist/, build/                     ← IGNORÉS — artefacts de build
│
└── workspace/                            ← TOUT ce qui est perso — SON PROPRE repo git, LOCAL
    │
    ├── .git/                             (historique local — AUCUN remote, jamais poussé)
    ├── .gitignore                        ← `secrets.md`
    │
    ├── README.md                         ← index du workspace
    ├── secrets.md                        ← IGNORÉ — PAT GitHub, API keys, procédures d'auth
    │
    ├── docs/                             ← SUIVI.md · BACKLOG.md · archives/ · réflexions, ADR
    ├── plans/                            ← plans phase 1, phase 2, roadmap
    └── notes/                            ← scratch, brouillons, captures de conv
```

### **DEUX repos git par projet** — et un seul va sur GitHub

| | `repo/` | `workspace/` |
|---|---|---|
| **Contenu** | l'app : ce qu'il faut pour cloner, builder, lancer | la mémoire : suivi, décisions, plans, archives |
| **Remote** | ✅ GitHub *(privé ou public)* | ❌ **aucun — jamais poussé** |
| **cwd de Claude Code** | ✅ | — *(accédé en `../workspace/`)* |
| **Sauvegarde hors-site** | GitHub | le **backup NAS** du dossier de travail |

**Pourquoi `workspace/` a son propre git.** Sans lui, il n'est versionné **nulle part** : toute suppression y est **irréversible**, et c'est la mémoire du projet qui part. Un `.gitignore` protège le repo du dossier — **il ne protège pas le dossier**.

**Pourquoi il n'a PAS de remote.** *(a)* Il porte ce qui ne doit jamais devenir public — noms de repos privés, incidents, adresses de hosts. *(b)* Le jour où `repo/` passe public, il n'y a **rien à nettoyer** : la frontière a été posée au jour 1. *(c)* Git ne sait pas « versionner sans pousser » — il pousse des **commits**, pas des dossiers. **Deux repos est le seul mécanisme.**

> ⚠️ **`secrets.md` est gitignoré dans `workspace/`.** Le repo n'a pas de remote *aujourd'hui* — mais s'il en gagnait un, **tout l'historique partirait d'un coup**. Un secret n'entre jamais dans un objet git. Conséquence assumée : ce fichier n'a **pas** de filet anti-suppression — la vérité du secret vit dans `.envrc`, `secrets.md` n'en est que la doc humaine.

---

## 3. Règle de décision — où mettre un fichier ?

Trois questions à se poser, dans l'ordre :

1. **Est-ce nécessaire pour cloner + builder + lancer l'app ?**
   → Oui : `repo/` **et** versionné.
   → Non : on passe à la question 2.

2. **Est-ce consommé par l'app ou par Claude Code au runtime, techniquement ?** (ex. `.env`, `.claude/settings.local.json`, `data/`)
   → Oui : `repo/` mais **ignoré** (doit être physiquement là mais ne doit pas fuiter).
   → Non : on passe à la question 3.

3. **C'est de la doc, des plans, des notes, des secrets personnels ?**
   → `workspace/` (hors du repo publié — mais **sous git**, dans son propre repo local : §2).

### Exemples concrets

| Fichier / dossier | Question 1 | Question 2 | Emplacement |
|---|---|---|---|
| `backend/src/*.ts` | Oui | — | `repo/backend/src/` versionné |
| `docker-compose.yaml` | Oui | — | `repo/` versionné |
| `README.md` | Oui (install/run) | — | `repo/` versionné |
| `.env` | Non | Oui (app runtime) | `repo/.env` ignoré |
| `.envrc` | Non | Oui (direnv → git/gh) | `repo/.envrc` ignoré |
| `.claude/settings.local.json` | Non | Oui (Claude Code) | `repo/.claude/` ignoré |
| `CLAUDE.md` | Non | Oui (Claude Code) | `repo/CLAUDE.md` ignoré |
| `node_modules/` | Non | Oui (Node runtime) | `repo/node_modules/` ignoré |
| `data/` (SQLite) | Non | Oui (app runtime) | `repo/data/` ignoré |
| Plan phase 2 | Non | Non | `workspace/plans/` |
| Schéma d'archi | Non | Non | `workspace/docs/` |
| Captures de réflexion | Non | Non | `workspace/notes/` |
| PAT GitHub, procédures d'auth | Non | Non | `workspace/secrets.md` |

---

## 4. Gestion des secrets

**Règle stricte** : aucun secret dans un fichier versionné. Jamais.

### Les 2 emplacements de secrets

| Emplacement | Contenu | Usage |
|---|---|---|
| `repo/.env` | Clés API **applicatives** (`ALCHEMY_API_KEY`, `DUNE_API_KEY`, `TELEGRAM_BOT_TOKEN`, …) — **pas le PAT** | Consommé par l'app au runtime et par Claude Code en dev |
| `repo/.envrc` | Le **`GITHUB_PAT`** du repo (secret de dev) + charge `.env` + `export GH_TOKEN=$GITHUB_PAT` | direnv : expose le PAT à git/gh, confiné au dossier |
| `workspace/secrets.md` | Procédures d'auth, pointeurs, valeurs humainement lisibles, dates d'expiration, où régénérer | Référence humaine + pointeur pour Claude Code |

> **Le secret GitHub vit à un seul endroit : `repo/.envrc` (`GITHUB_PAT`).** Le remote git reste en **URL nue** (jamais `https://<PAT>@github.com/...`), et `.envrc` réexporte ce PAT en `GH_TOKEN` dans le shell du dossier. Aucun secret en clair dans `.git/config`.

### Pourquoi cette séparation

- `.env` = format technique consommable par l'app et les scripts (pas d'explications, juste des paires clé=valeur).
- `workspace/secrets.md` = format humain : *où* trouver, *comment* régénérer, *quels* scopes, *quand* ça expire. Indispensable pour reprendre depuis un backup NAS sur une nouvelle machine.

### Duplication à éviter

- Une clé API ne doit exister **qu'à un seul endroit** : `.env`. Si Claude Code en a besoin, il lit `.env` directement. Ne JAMAIS dupliquer dans `settings.local.json`.

---

## 5. Authentification GitHub

**Principe : séparer la lecture (large, inoffensive) de l'écriture (étroite, par repo). Aucun token RW large nulle part.** Deux canaux d'auth étanches : le **cloud** (claude.ai) et le **local** (CC en terminal/desktop) ne partagent pas le même mécanisme — modifier l'un n'affecte pas l'autre.

### Vue d'ensemble des accès

| Acteur | Token / mécanisme | Périmètre | Durée |
|---|---|---|---|
| **Toi** | Interface web github.com | Tout | — |
| **Chat / Projects (cloud)** | GitHub App Claude, installée par owner | Lecture seule des repos autorisés (perso + orgs) | révocable |
| **CC — lecture** | PAT fine-grained **public-RO** (`claude-ro`) dans `gh` | Tout le public, 5000 req/h, **zéro privé** | **sans expiration — assumé** (voir ci-dessous) |
| **CC — écriture** | PAT fine-grained RW **1 par repo** dans `repo/.envrc` | Ce repo uniquement | **90 jours** + alerte J-14 |
| **Dockhand** | PAT classic RO (`dockhand-ro`) — compte actarus314 | Tous repos (perso + orgs) | 1 an |

### Lecture publique + auth Git par défaut → `gh` en public-RO

`gh` CLI porte un PAT **fine-grained « Public repositories (read-only) »** : lecture de tout le GitHub public à 5000 req/h, **aucun accès aux privés**. C'est le token par défaut de toute session CC, et il est inoffensif s'il fuit.

> ⚠️ **Ne PAS utiliser `gh auth login` en flow web/OAuth** : il impose toujours le scope `repo` (RW sur TOUS tes repos). On installe à la place un PAT aux droits choisis via `--with-token`.

**Setup initial (une fois par machine) :**
```bash
brew install gh direnv
# Créer un fine-grained PAT "Public repositories (read-only)" sur github.com
echo "<PAT-public-RO>" | gh auth login --with-token
gh auth setup-git                              # git délègue à « gh auth git-credential »
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc   # hook direnv
```

**Vérification :**
```bash
gh auth status
gh api rate_limit --jq .rate     # limit = 5000
```

La lecture des repos **privés** depuis CC n'est volontairement pas configurée en local (un classic `repo` serait du RW déguisé ; un fine-grained ne couvre qu'un owner à la fois). Elle se fait via la **GitHub App côté Chat/Projects**.
Corollaire assumé : depuis un terminal, Claude **ne voit ni les organisations ni les repos privés** — il faut les lui nommer.

> ⚠️ **Piège — une org PEUT refuser `claude-ro`, même en lecture publique.**
> Une organisation peut imposer une **durée de vie maximale** aux PAT fine-grained *(Settings de l'org → Personal access tokens → « Require tokens to expire »)*.
> Si cette limite existe, `claude-ro` — **sans expiration** — est rejeté en **403** sur **tout** repo de l'org, **y compris public** :
> *« The '<org>' organization forbids access via a fine-grained personal access tokens if the token's lifetime is greater than 90 days. »*
> **Symptôme déroutant** : le même `gh api` **réussit depuis `repo/`** (direnv y expose le PAT 1-repo, 90 j) et **échoue depuis ailleurs** (`gh` retombe sur `claude-ro`). Le token en cause n'est pas celui qu'on croit.
> Le piège reste valable pour toute org qui l'active — la limite peut aussi être levée après coup côté org.

> **`claude-ro` est volontairement SANS EXPIRATION** (vérifié : l'API ne renvoie aucun header `GitHub-Authentication-Token-Expiration`). Ce n'est pas un oubli.
> Une durée de vie courte ne protège que contre la **persistance après vol du secret** — or ce token est en lecture seule sur du **public** : un attaquant qui le vole n'obtient que ce qui est déjà public. Lui imposer une rotation serait une corvée récurrente pour un gain nul.
> *(Seul garde-fou côté GitHub : révocation automatique après 1 an d'inactivité.)*
> **Le raisonnement inverse s'applique aux PAT d'écriture** — eux touchent du code privé et publient : 90 jours, avec alerte J-14.

### Écriture (push, PR, issues) → PAT fine-grained 1-repo exposé par direnv

- **Un PAT par repo**, créé en fine-grained, *Only select repositories* → **ce repo uniquement** (owner = compte ou org du repo).
- **Permissions standard homogènes** : `Contents R/W`, `Metadata R`, `Pull requests R/W`, `Issues R/W`, `Workflows R/W`, `Actions R/W`.
  **+ permissions d'alertes**, pour la maintenance sécu en autonomie : Dependabot & Code scanning `R/W`, Secret scanning `R`.
  *(Matrice détaillée : `github-repo-config.md` §2.)*
  **Tout le reste : No access** — et **jamais** `Administration`.
- Stocké dans `repo/.envrc` comme `GITHUB_PAT`. **Remote en URL nue** (jamais de PAT dans l'URL).
- Exposé à git/gh **uniquement dans le dossier** par direnv. `repo/.envrc` (gitignoré) contient le PAT et reste **sourçable en bash** (pas de builtin `dotenv`, pour l'outil Bash non-interactif — cf. plus bas) :
  ```
  set -a; [ -f .env ] && . ./.env; set +a   # charge les vars app de .env (équivalent bash de `dotenv`)
  export GITHUB_PAT=<PAT 1-repo>
  export GH_TOKEN="$GITHUB_PAT"
  ```
  puis `direnv allow` une fois. En entrant dans le dossier → push/PR via le PAT du repo ; en sortant → retour au public-RO.
- Documenté dans `workspace/secrets.md` : date d'expiration, repo ciblé, lien de régénération.

**Usage (direnv charge tout, pas de `source .env`) :**
```bash
git push                                   # auth via le PAT du repo
gh pr create --title "..." --base main
gh issue list && gh run list
```

> **Piège Workflows :** sans la permission `Workflows: R/W`, GitHub **rejette** tout push touchant `.github/workflows/`, même avec `Contents: R/W`. La garder dans le standard évite la surprise.

> 🔴 **Limite ASSUMÉE de ce modèle — `gh pr checks` et `gh pr view` ne fonctionnent pas.**
> Les deux lisent `statusCheckRollup`, qui exige la permission **`Checks`**. Elle est **documentée** par GitHub mais **absente de l'UI** des PAT fine-grained : **impossible à accorder** *(github/community#129512, cli/cli#12597)*. Ce n'est **pas** un oubli dans la matrice ci-dessus — **il n'y a rien à y ajouter**.
> **Ce n'est pas cosmétique** : la seule barrière du mode privé (*« ne jamais merger une PR rouge »*, §18) reposait sur `gh pr checks`. → Elle passe par `gh run list --commit <sha>` (`Actions: read`, déjà là). **La commande exacte, et le piège du faux vert : §18.**
> *(La GitHub App, elle, peut recevoir `Checks` — mais elle reste écartée pour les motifs du tableau ci-dessous : on ne rouvre pas le modèle d'auth pour une commande CLI qui a un substitut à coût nul.)*

### Expiration : 90 jours + alerte automatique (jamais subie)

**Tout nouveau PAT d'écriture est borné à 90 jours.** L'expiration ne doit **jamais** être découverte en pleine session, un `git push` en main.

`repo/.envrc` embarque une **alerte automatique** : GitHub renvoie la date de fin dans le header `GitHub-Authentication-Token-Expiration`, lu une fois par jour (cache dans `.git/`, jamais commité). À **J-14**, le terminal affiche :

```
  /!\  GITHUB_PAT expire dans 12 jour(s), le 2026-10-11.
      Regenerer (90 j, memes permissions) : https://github.com/settings/personal-access-tokens
      Puis : remplacer le PAT de ce .envrc + la date dans ../workspace/secrets.md
```

Silencieux quand tout va bien, hors ligne, ou si le PAT n'expire pas. Message distinct si le PAT est **déjà** mort.
C'est ce qui rend les 90 jours indolores : la rotation est **annoncée**, pas subie. Sans cette alerte, une durée courte n'est qu'une panne surprise de plus.

### Une seule convention pour `.envrc` — l'ancienne est bannie

| | ✅ Convention actuelle | ❌ Ancienne convention (à migrer) |
|---|---|---|
| Chargement de `.env` | `set -a; [ -f .env ] && . ./.env; set +a` | `dotenv` (builtin **direnv**) |
| Où vit le PAT | `repo/.envrc` (`GITHUB_PAT`) | `repo/.env` |

Deux raisons, toutes deux constatées sur des projets réels :
- **`dotenv` n'existe pas en shell non-interactif.** L'outil Bash de Claude Code fait `source ./.envrc` → `dotenv: command not found` → le PAT n'est **jamais chargé** → aucun push possible. Le `.envrc` doit rester **sourçable en bash pur**.
- **Le PAT dans `.env` fuite dans les conteneurs.** Un `docker-compose.yaml` avec `env_file: .env` injecte `GITHUB_PAT` dans le conteneur — visible via `docker inspect`. Le `.env` est réservé aux clés **applicatives** ; le PAT vit dans `.envrc`, et **nulle part ailleurs**.

### Mécanismes évalués puis écartés — ne pas rouvrir sans fait nouveau

Le PAT fine-grained **1-repo** est l'optimum *(recherche complète : `workspace/RECHERCHE-auth-github.md`)*. Ont été évalués puis **écartés** :

| Mécanisme | Motif d'écartement (vérifié) |
|---|---|
| **GitHub App** (installation token) | En workflow `git push`, elle n'apporte **ni identité `[bot]` ni commits `Verified`** : le token n'authentifie que le **transport**, l'auteur du commit est figé par `git config`. Ces bénéfices n'existent que pour les commits créés **via l'API**. Restent une clé `.pem` qui **ne périme jamais** et une dépendance tierce. |
| **GitHub App + `ghtkn`** (user token 8 h) | Aucun refresh silencieux : device flow **navigateur ~3×/jour**, et l'outil **refuse par design** qu'un agent le déclenche. Incompatible avec toute autonomie. |
| **PAT classic** | Scope `repo` = **tout-ou-rien** : RW sur tous les repos, publics **et** privés, de tous les owners. `public_repo` n'ouvre aucun privé. Aucun scope ne vise **un seul** repo. Blast radius maximal. |
| **1 PAT par owner** (au lieu d'1 par repo) | Économise quelques minutes/an en **multipliant par N le blast radius** d'une session. Le 1-PAT-par-repo **est** le scoping. |
| **PAT dans le Keychain** | Casse le principe « un seul dossier à copier » (§2/§18) : le secret ne suivrait plus le dossier sur une nouvelle machine. |

> **Ce qu'aucun mécanisme d'auth ne règle.**
> Face à une **injection de prompt** (cf. GitLost, 2026), l'agent détourné dispose d'un token **valide au moment de l'attaque** — sa durée de vie n'y change rien.
> Une expiration courte ne limite que la **persistance après vol du secret**, pas l'usage immédiat.
> La seule mitigation qui mord est le **périmètre** : défaut public-RO, accès privé escaladé **délibérément**, et **jamais** le cumul credential large + shell + ingestion de contenu non fiable.

### Shell non-interactif (outil Bash de Claude Code) — direnv NON chargé

Tout ce qui précède suppose un shell **interactif**, où le hook direnv a tourné.
Or **l'outil Bash de Claude Code lance des shells non-interactifs** : le hook direnv **ne se déclenche pas**.
Conséquence en chaîne : `GITHUB_PAT`/`GH_TOKEN` sont **absents de l'env** → `git` retombe sur le credential helper de la machine (souvent `osxkeychain`, qui porte le PAT **public-RO**) → **403 même en simple lecture d'un repo privé**.
Le tout alors que le bon PAT est **bien présent** dans `.envrc` — d'où un symptôme parfaitement déroutant.

> **Symptôme** : `git fetch/pull/push origin` → `403` / `Write access to repository not granted`, alors que `repo/.envrc` contient le bon `GITHUB_PAT`.

**Le mauvais réflexe à bannir** : mettre le PAT dans l'URL (`https://x-access-token:$TOKEN@github.com/...`) — ça l'expose (ps, historique, reflog, `.git/config`). **L'URL reste nue, toujours.**

**Procédure propre (vérifiée)** — un helper credential **local** qui lit `$GITHUB_PAT` depuis l'env, configuré une fois (persiste dans `repo/.git/config`, **aucun secret stocké**, juste le nom de variable ; le `""` initial réinitialise la liste pour passer devant osxkeychain) :
```bash
git config --local credential."https://github.com".helper ""
git config --local --add credential."https://github.com".helper \
  '!f() { echo username=x-access-token; echo "password=${GITHUB_PAT}"; }; f'
```
Puis, **à chaque session, depuis `repo/`**, charger l'env manuellement (direnv ne le fait pas ici) :
```bash
set -a; source ./.envrc; set +a      # GITHUB_PAT + GH_TOKEN dans l'env (le helper lira GITHUB_PAT)
git push origin <ref>                  # URL NUE — token fourni par le helper depuis l'env
gh pr create / gh pr merge ...         # gh via GH_TOKEN
```
> Alternative équivalente si `gh auth setup-git` est configuré **globalement** sur la machine : le simple `export GH_TOKEN="$GITHUB_PAT"` suffit (git délègue à `gh auth git-credential` qui renvoie `GH_TOKEN`). Le helper local ci-dessus est plus robuste car il ne dépend pas de l'état global de la machine.

---

## 6. `CLAUDE.md` — instructions locales pour Claude Code

Fichier présent dans `repo/CLAUDE.md` mais **ignoré par Git**. Claude Code le lit automatiquement à chaque session (il est dans cwd).

**Contenu type** :
- Description courte du projet (une ligne).
- Commandes utiles (`docker compose up`, `npm run dev`, etc.).
- Pointeurs vers `workspace/` : où sont les plans, les docs, les secrets.
- Conventions de code spécifiques au projet.
- Ce qu'il ne faut surtout pas toucher (sous-modules, code tiers, etc.).

**Ce que `CLAUDE.md` ne contient JAMAIS** :
- Aucun secret, token, clé API (même s'il est ignoré, discipline zéro-secret dans un fichier *nommé* → en cas d'erreur de `.gitignore`, on ne fuite pas).
- Aucune valeur volatile qui change chaque semaine.

Un futur cloneur qui n'a pas le `workspace/` (parce qu'il vient de GitHub seul) travaillera sans `CLAUDE.md`, et c'est voulu : le repo reste 100 % impersonnel.

---

## 7. `.claude/` — config Claude Code du projet

Dossier entièrement **ignoré par Git**. Contient :

- `settings.local.json` : permissions autorisées pour ce projet, variables d'env spécifiques Claude Code, hooks locaux.
- Éventuellement `commands/`, `agents/`, `skills/` si tu crées des outils projet-spécifiques pour Claude Code.

**Fichiers que Claude Code lit dans `.claude/`** :
`settings.json`, `settings.local.json`, `commands/`, `agents/`, `skills/`, `rules/`.

**Fichiers à NE PAS créer dans `.claude/`** :
- `launch.json` (format VS Code, ignoré par Claude Code, confusion classique).
- Tout autre fichier qui n'est pas dans la liste ci-dessus.

---

## 8. Mémoire persistante de Claude Code

Stockée par Claude Code dans `~/.claude/projects/<hash-du-path>/memory/`, où `<hash-du-path>` est dérivé du chemin absolu du projet (ex. `-Users-romain-Documents-Claude-dEURO`).

**Conséquence** : si tu renommes le dossier du projet, Claude Code crée un **nouveau** dossier de mémoire et perd le lien avec l'ancien.

**Procédure de renommage** :
1. Renommer le dossier du projet (`~/Documents/Claude/ancien` → `~/Documents/Claude/nouveau`).
2. Fusionner le contenu de l'ancien dossier de mémoire dans le nouveau :
   ```bash
   rsync -av ~/.claude/projects/-Users-romain-Documents-Claude-ancien/ \
             ~/.claude/projects/-Users-romain-Documents-Claude-nouveau/
   rm -rf ~/.claude/projects/-Users-romain-Documents-Claude-ancien/
   ```
3. Vérifier que `/resume` propose bien les anciennes conversations.

---

## 9. `.gitignore` type

```gitignore
# secrets & local config
.env
.env.local
.envrc
.claude/
CLAUDE.md

# deps
node_modules/

# build artifacts
dist/
build/
.tsbuildinfo
.vite/

# runtime data
data/
*.db
*.db-journal
*.db-wal
*.db-shm

# misc
.DS_Store
*.log
*.bak
*.bak-*
```

**Maintenir ce fichier vivant** : si une entrée ne correspond à aucun fichier du projet (ex. `dist/` qui est généré uniquement dans Docker, jamais sur le Mac), la laisser n'est pas nuisible — c'est du défensif. En revanche, si tu as ajouté un nouveau type de fichier perso, l'ajouter au `.gitignore` immédiatement.

---

## 10. Créer, configurer, faire évoluer un projet → **le RUNBOOK**

**La procédure complète vit dans `RUNBOOK.md`** — et **elle seule fait foi** : ordre des gestes, **qui les fait**, URL directes, permissions exactes, commandes complètes.

**Ne pas la dupliquer ici.** Deux copies d'une procédure divergent, et c'est celle qu'on ne relit pas qui envoie chercher une permission qui n'existe plus.

| Le RUNBOOK couvre | § |
|---|---|
| **Créer un projet** *(les 3 questions · les 2 PAT · `direnv allow` · la révocation)* | §1 |
| **Travailler au quotidien** *(feat → PR → CI verte → merge)* | §2 |
| **Publier une version** *(CHANGELOG → tag → Release + image)* | §3 |
| **Basculer PRIVÉ → PUBLIC** *(le moment le plus dangereux du cycle de vie)* | §4 |
| **Acquérir / retirer une capacité** sur un repo vivant | §5 |
| **Maintenance** *(Dependabot, Renovate, alertes, rotation du PAT)* | §6 |
| **Ce que l'assistant NE PEUT PAS faire** *(et pourquoi)* | §7 |

> 🔴 **Le présent document dit le POURQUOI ; le RUNBOOK dit l'ORDRE DES GESTES.**
> En cas d'écart entre les deux : **le RUNBOOK fait foi sur la procédure**, ce document sur les **conventions** — et **l'écart est un défaut à corriger**, pas un arbitrage à faire en passant.

**Une skill Claude Code le déroule** *(`new-project`)* : elle s'arrête à chaque geste de Romain, donne l'URL et les valeurs exactes, attend confirmation, puis vérifie. Voir `workspace/SKILLS.md`.

## 11. Pièges classiques à éviter

- **Dupliquer une clé API** dans `.env` et `settings.local.json` → source de vérité ambiguë. Toujours une seule copie, dans `.env`.
- **Mettre un secret dans `CLAUDE.md`** même ignoré → discipline zéro-secret sur tout fichier *nommé d'après une convention*. Un jour `.gitignore` est mal configuré, le secret fuit.
- **Créer `launch.json` dans `.claude/`** en pensant que Claude Code le lit → il ne le lit pas. Si besoin de debug VS Code, c'est `.vscode/launch.json`.
- **Mettre des docs de réflexion dans `repo/docs/`** → ils finissent sur GitHub alors qu'ils sont personnels. `repo/docs/` est pour la doc technique destinée à un cloneur ; les réflexions vont dans `workspace/docs/`.
- **Renommer le dossier sans fusionner la mémoire Claude Code** → perte de l'historique `/resume`.
- **Faire `gh auth login` en flow web/OAuth** → ça réinstalle le scope `repo` (RW sur TOUS tes repos), exactement ce qu'on évite. Toujours `gh auth login --with-token` avec le PAT public-RO.
- **Mettre le PAT dans l'URL du remote** (`https://<PAT>@github.com/...`) → secret en clair dans `.git/config`. Remote en URL nue, PAT exposé par direnv uniquement.
- **Oublier `direnv allow`** (ou le hook dans `~/.zshrc`) → `GH_TOKEN` non chargé → `git push` retombe sur le public-RO et échoue. Symptôme : push refusé alors que le PAT est bien dans `.env`.
- **Croire que direnv charge le PAT dans l'outil Bash de Claude Code.**
  Il lance des shells **non-interactifs** : le hook direnv ne tourne pas → `git`/`gh` renvoient **403, même en lecture**.
  Fix : helper credential local lisant `$GITHUB_PAT`, + `source ./.envrc` une fois par session (§5, « Shell non-interactif »).
  ⚠️ **Ne jamais** dépanner en mettant le PAT dans l'URL du remote — c'est une fuite en clair dans `.git/config`.
- **Utiliser `dotenv` (builtin direnv) dans `.envrc`** → le fichier n'est plus **sourçable en bash** : `source ./.envrc` en shell non-interactif donne `dotenv: command not found`, le PAT n'est jamais chargé, aucun push possible. Toujours `set -a; [ -f .env ] && . ./.env; set +a`.
- **Mettre le PAT dans `.env` au lieu de `.envrc`** → un `docker-compose.yaml` avec `env_file: .env` **injecte le PAT GitHub dans le conteneur** (visible en `docker inspect`). `.env` = clés **applicatives** uniquement ; le PAT vit dans `.envrc`, nulle part ailleurs.
- **Laisser un PAT expirer sans le voir venir** → panne surprise en plein `git push`. L'alerte J-14 du `.envrc` (§5) le signale à l'avance : ne pas la retirer en copiant le fichier.
- **Lancer deux sessions Claude Code (ou deux personnes) sur le même `repo/`.**
  Elles partagent `HEAD`, l'index et les fichiers — donc elles se télescopent.
  Un `checkout -b` **bascule la branche de l'autre** · les edits simultanés s'écrasent · `gh pr merge --delete-branch` plante (*« main already checked out »*).
  Fix : **un working tree isolé par session** — `git worktree` ou clone séparé (§12, « Travail concurrent »).
- **Créer un PAT owner-scoped au lieu de 1-repo** → une fuite expose tous les repos de l'owner. Toujours *Only select repositories* = ce repo.
- **Laisser grossir `.gitignore` avec des entrées obsolètes** → pas nuisible mais brouille la lecture. Nettoyer périodiquement.
- **Mettre un rappel calendrier pour les PAT** → inutile désormais : l'alerte **J-14** du `.envrc` (§5) s'en charge. Les PAT d'écriture sont à **90 jours** ; `claude-ro` (lecture publique) n'expire **pas**, volontairement.

---

## 12. Politique de branches — **elle dépend d'UNE capacité, pas de l'archétype**

> La politique de branches dépend de **trois capacités indépendantes**, pas d'un archétype figé : réduire le choix à `static`/`node` fusionne trois questions distinctes et casse dès qu'on sort du cas standard *(cf. DORA · Fowler · ThoughtWorks Radar)*.

### Les 3 CAPACITÉS — indépendantes, composables

`--type` ne décide plus que **la TOOLCHAIN** (quel `ci.yml` : `static` = aucun npm · `node` = npm/tests/types). Tout le reste découle de **trois questions qui n'ont rien à voir entre elles** :

| Capacité | La question à se poser | Ce qu'elle déclenche |
|---|---|---|
| **`--pages`** | Le site est-il servi par **GitHub Pages** ? | `pages.yml` |
| **`--artefact`** | Le repo **publie-t-il une image que quelqu'un d'AUTRE déploie** ? *(auto-hébergeurs, NUC…)* | `docker-publish.yml` (**`build-check` + Trivy**) · Dependabot `docker` · **ruleset tags** · **immutable releases** · **package ghcr PUBLIC** |
| **`--staging`** | Existe-t-il un **host à VALIDER** avant la prod ? | branche **`develop`** · ruleset `develop` · merge commit sur `main` · **flux 3 étages** |

> 🔴 **`develop` ne découle PAS de Docker — il découle du STAGING.**
> Un projet **node sans host à valider** n'a **pas** besoin de `develop`. Et **`rozo-bridge` packagé en image non plus** : il n'y a aucun palier intermédiaire, l'image *est* la page servie par nginx.

**Le besoin d'un palier de staging vient du DÉPLOIEMENT, pas du langage ni du goût.**

### Les combinaisons réelles

| Cas | `--type` | pages | artefact | staging | Flux |
|---|---|---|---|---|---|
| Site Pages *(raccourci `--type static`)* | static | ✅ | — | — | **GitHub Flow** — `main` + `feat/` |
| **`rozo-bridge` + Docker** *(des tiers l'auto-hébergent)* | static | ✅ | ✅ | — | **GitHub Flow** + tag `v*` → image |
| Page hébergée **hors** Pages | static | — | ✅ | selon | selon le staging |
| App Docker → NUC *(raccourci `--type node`)* | node | — | ✅ | ✅ | **3 étages** — `feat/` → `develop` → `main` + tag |
| Projet node **sans** staging | node | — | ✅ | — | **GitHub Flow** + tag |

**Raccourcis rétro-compatibles** : `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging`. Dès qu'une capacité est passée explicitement, on **compose** (`--no-staging` retire du raccourci).

⚠️ **`init-project.sh` REFUSE `--staging` sur un site Pages sans artefact** : Pages *est* la prod, il n'y a **rien à valider** — la branche serait un rituel vide qui dérive jusqu'à ce que le merge cesse d'avoir lieu.

**Le triple filtre reste ce qui aurait arrêté l'incident dEURO** (raconté plus haut dans ce §12) — mais seulement là où il existe un host à valider. Ailleurs, il n'aurait rien filtré.

**Git Flow est mort** : `nvie/gitflow` a été **archivé par son auteur le 14/10/2025**. Ne pas le ressortir.

### Pourquoi `develop` n'est PAS l'anti-pattern qu'on lui reproche — la nuance est structurante

Les *environment branches* (une branche par environnement) sont un anti-pattern documenté : Fowler (« *soon leads to a world of misery* »), ThoughtWorks (*environmental drift*). **Mais le critère n'est pas le nom de la branche — c'est ce qui pilote le déploiement.**

> ✅ **Ce standard est du bon côté** : la prod ne suit **jamais** une branche, elle suit un **tag épinglé** (`APP_IMAGE_TAG=X.Y.Z`, §13). On promeut un **artefact**, pas une branche — c'est exactement l'alternative que DORA et ThoughtWorks recommandent *à la place* des environment branches.
>
> ❌ **On y bascule** le jour où `develop` devient longue (le code diverge par environnement) ou si un host fait `git checkout develop` comme source de vérité de son déploiement.
>
> **Règle qui en découle** : **`develop` reste courte** — merge en **jours**, pas en semaines. C'est la seule condition à tenir.

### Branches

- **`main`** : prod. Protégée (ruleset). Avec la capacité **`artefact`**, la prod tourne sur un **tag pinné**, jamais sur la branche.
- **`develop`** *(capacité **`staging`** uniquement — **PAS** « node », **PAS** « Docker »)* : staging. Protégée. **Courte durée.**
- **`feat/<topic>`** : depuis `develop` **si `staging`**, sinon depuis `main`. Supprimée au merge (auto).
- **Tags `v*`** : **immuables** — un ruleset interdit leur suppression et leur déplacement. Sans ça, le pin de version du §13 ne garantit rien (cf. §17).

### Flux complet

```bash
# Étape 1 — démarrage du sujet, sur le poste de dev
git checkout develop && git pull
git checkout -b feat/<topic>
# … commits …
docker compose up --build -d  # validation locale
# OK → on passe à l'étape 2

# Étape 2 — staging, le code part sur develop
git checkout develop
git merge --no-ff feat/<topic> -m "<topic> → staging"
git push origin develop
# Sur le NUC : git checkout develop && git pull && docker compose up --build -d
# … validation fonctionnelle …
# OK → on passe à l'étape 3

# Étape 3 — prod, on tag depuis main
gh pr create --base main --head develop --title "vX.Y.Z: <changelog résumé>"
gh pr merge --merge          # garde l'historique des commits feat/*
# ⚠️ REPO PRIVÉ : ce merge vient de SUPPRIMER `develop` (delete-branch-on-merge, et aucun ruleset
#    ne la protège tant que le repo est privé). La recréer AUSSITÔT — voir l'encadré ci-dessous.
git checkout main && git pull
git tag -a vX.Y.Z -m "vX.Y.Z — <résumé>"
git push origin vX.Y.Z       # déclenche le workflow de release CI
# Le NUC : DEURO_IMAGE_TAG=X.Y.Z dans .env, docker compose pull && up -d
```

> 🔴 **En PRIVÉ, la mise en production DÉTRUIT la branche de staging.**
> `delete-branch-on-merge` supprime la branche **source** de **toute** PR mergée — donc **`develop`**, au merge de la PR `develop → main` de l'étape 3. **En public**, le ruleset `develop` (règle `deletion`) le refuse ; **en privé, aucun ruleset n'existe** *(§18)* et la branche disparaît **en silence**.
> **Et le dégât est en cascade** : au rejeu suivant, `configure-repo.sh` ne voit plus `develop`, en déduit « pas de staging », **ne pose pas son ruleset** et **remet `main` en squash-only** — or **squasher `develop` dans `main` fait diverger les deux branches à chaque cycle**. La promotion suivante devient **impossible**. *Le succès de la mise en prod casse le cycle suivant.*
> **→ Recréer `develop` immédiatement après la promotion :** `git switch -c develop main && git push -u origin develop`
> *(Le script le détecte désormais : il compare ce que le repo **publie** — le bloc `## Branching` de `CONTRIBUTING.md` — à ce qui **existe**. Vécu sur test003, 2026-07-14.)*

Pour du trivial (typo doc, rename de variable, fix de query sans impact runtime) sur projet solo : main direct reste acceptable.

### Travail concurrent — plusieurs sessions / intervenants

> Le flux ci-dessus suppose **un working tree par intervenant**. Le piège n'est pas Git mais le **partage d'un même dossier de travail** — cas typique : deux sessions Claude Code lancées sur le même `repo/`.

**Ce qui est partagé par dossier** (donc dangereux à plusieurs au même endroit) : le `HEAD` (branche courante), l'`index` (staging) et les fichiers sur disque. Conséquences :

- un `git checkout -b` bascule la branche **de l'autre** sans prévenir ;
- édition simultanée d'un même fichier → dernier qui écrit gagne (perte silencieuse) ;
- `git add` peut embarquer le travail non commité de l'autre ;
- symptôme révélateur : `gh pr merge --delete-branch` → *« 'main' is already checked out at … »* (le merge distant réussit quand même, seule la suppression locale de branche échoue → supprimer la branche distante à la main).

**Règle : un working tree isolé par intervenant.** Deux options :

| Option | Quand | Commande |
|---|---|---|
| **Clones séparés** | personnes/machines différentes | `git clone` chacun de son côté |
| **`git worktree`** | même machine, plusieurs sessions/tâches | `git worktree add -b <branche> /chemin/iso origin/main` … `git worktree remove <chemin>` |

Le worktree partage le `.git` (objets, branches, remotes) mais a son **propre dossier et son propre `HEAD`**.
On édite, commite, pousse et ouvre une PR **sans jamais toucher l'arbre de l'autre**.
**Déployer** depuis un worktree sans empoisonner le `./data` du dossier principal : `docker build` **depuis le worktree** (l'image est *baked*), puis `docker compose up -d` **depuis le dossier principal** (les volumes réels y sont).
Nettoyage : `git worktree remove <chemin>` + suppression de la branche.

**Discipline une fois les arbres isolés :**

- `git fetch` + rebase/pull **avant** chaque push (toujours pousser par-dessus l'état distant à jour → pas de non-fast-forward) ;
- **jamais de `--force`** sur une branche partagée (`--force-with-lease` si vraiment nécessaire) ;
- `git add` **ciblé** (jamais `git add -A` à l'aveugle dans un arbre partagé).

**Garde-fou serveur — branch protection sur `main` (et `develop`)** : transforme la discipline en règle imposée. PR obligatoire (pas de push direct), **CI verte requise** (`npm test` + `typecheck`), interdiction de force-push et de suppression de branche, linear history. C'est le filet le plus efficace contre le télescopage sur le distant.

**Déploiement / état partagé hors Git.**
Un seul intervenant rebuild/déploie `main` HEAD à la fois.
Et **ne jamais muter l'état partagé hors Git pendant qu'un service tourne.**
Exemple vécu : ouvrir une SQLite **en WAL depuis l'hôte** alors que le conteneur l'utilise casse le mmap `-shm` sur virtiofs (Docker Desktop macOS) → `disk I/O error`.
*(Données intactes ; correctif : `docker restart`.)*
Pour inspecter une base : passer par l'API ou `docker exec` — **jamais** une connexion directe depuis le Mac.

### Pourquoi 3 étapes

**L'incident qui justifie tout ce qui précède — dEURO.**
Un push **direct sur `main`** (commit `5b78811`) retire la directive compose `user:`, en croyant faire tourner le conteneur en root.
Or l'image distroless `:nonroot` **impose** l'UID 65532.
SQLite perd donc l'écriture sur le bind mount `./data` → `SQLITE_READONLY_DIRECTORY`, **en prod, sur le NUC**.
Le bug atteint `main`, puis `:latest` sur ghcr.io, et **le NUC l'a pull avant qu'on le détecte**.
Le triple filtre Mac → NUC/`develop` → NUC/`main` l'aurait arrêté **deux fois**.

### Build vs pull d'image

Pour les étapes 1 et 2, **build local** sur l'host cible (`docker compose up --build`) suffit. Il est tentant d'étendre le pipeline GHA pour publier des images `:branch-feat-…` ou `:develop` consommables par `docker compose pull` — ne le faire que si :
- plusieurs hosts doivent partager exactement le même artefact (par ex. multi-NUC) ;
- le host cible n'a pas le toolchain de build ;
- la build locale est trop lente sur le host (clusters arm64 anciens).

Pour un projet solo Mac+NUC, build local = chemin court. Le workflow CI ne sert que pour la prod (tag versionné + `:latest`).

### Quand sauter une étape

- **Patch hotfix** : créer un `fix/<topic>` depuis `main`, valider en local, merger directement dans `main`, tag patch (`vX.Y.Z+1`). Skip staging si l'urgence le justifie ET la régression est très ciblée.
- **Documentation** ou **renommage** sans impact runtime : commit direct sur `main`.
- **Migration DB** ou **changement de Dockerfile/compose** : **jamais** sauter staging. La règle.

---

## 13. Pin de version en production

> ⚠️ **Le package ghcr PEUT être privé — même sur un repo public. Ça se VÉRIFIE, ça ne se suppose pas.**
> **Compte PERSO** : un package publié depuis un repo **public** hérite de son accès → **tirable aussitôt**, aucun geste *(vérifié sur test003, 2026-07-14 : HTTP 200 sans rien faire)*.
> **ORGANISATION** : il peut être **PRIVÉ** *(défaut d'org — constaté sur test002)* → le `docker compose pull` du host reçoit **403**, et le pin ci-dessous ne sert à rien : **il n'y a rien à tirer**.
> → **`configure-repo.sh` interroge le registre ANONYMEMENT**, exactement comme le host de prod, et ne réclame le geste *(Package settings → Change visibility, **aucune API**)* **que si le pull échoue**. *Un job « Publish image » vert ne prouve RIEN.*

Sur les hosts de production (NUC, serveurs déployés), **épingler le tag d'image** dans le `.env` du host :

```
APP_IMAGE_TAG=1.1.0
```

Jamais `:latest` en prod. Le but : un déploiement doit nécessiter un `git tag` explicite, pas qu'un push sur `main` propage automatiquement.

Sur les hosts de dev (Mac local) : `:latest` ou pas de pin du tout, c'est OK.

### Pourquoi

`:latest` est un tag mutable qui suit la branche `main`. Sans pin, un push de WIP sur main → workflow de release → `:latest` mis à jour → `docker compose pull` côté prod ramène potentiellement du code non validé. Avec un pin versionné, la prod est figée et un upgrade demande une action humaine consciente (changer le tag).

---

## 14. Durcissement Docker (sécurité de déploiement)

> Pratiques de sécurité validées pour **tout service Docker** du homelab (actarus314). Dérivé de la skill `docker-compose-security` + cheatsheet Docker (section Sécurité). Complète les §12-13 (workflow & pin de version).

### Règles absolues

| Règle | Détail |
|---|---|
| `version:` dans compose | **Jamais** — ligne interdite dans tous les `docker-compose.yml` |
| `sudo` | Toujours préfixer les commandes docker (NUC) |
| Convention volumes | `/docker/<service>/` pour tous les bind mounts sur l'hôte |
| Nommage image | Chemin complet dès le build : `ghcr.io/actarus314/<image>:tag` |
| `--privileged` | **Jamais** sauf nécessité absolue documentée |
| Ports internes | `127.0.0.1:PORT_HOTE:PORT_CONTAINER` sauf exposition publique explicite |
| Réseau | Un réseau **bridge dédié** par service/stack |

### Philosophie de durcissement

On **laisse `root:root`** (défaut Docker). Un UID non-root *partagé* entre containers n'apporte rien : le mouvement latéral reste possible. Le vrai gain vient des **directives compose**. Ordre d'impact réel :

1. Mises à jour kernel + docker-ce régulières → bloque les évasions CVE.
2. `cap_drop: [ALL]` + `no-new-privileges` → fort, facile à ajouter.
3. `read_only: true` + `tmpfs` → bloque les payloads en écriture.
4. `pids_limit` + `mem_limit` → anti-épuisement ressources hôte.
5. UID non-root **distinct par service** → utile seulement si un UID différent par service.

### Template compose sécurisé

```yaml
services:
  backend:
    image: ghcr.io/actarus314/mon-image:${IMAGE_TAG:-latest}
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp                      # seul point d'écriture container, en RAM
    cap_drop: [ALL]               # zéro capability Linux
    security_opt:
      - no-new-privileges:true    # bloque escalade via setuid/setgid
    pids_limit: 256               # protection fork bomb
    mem_limit: 512m               # protection épuisement mémoire
    volumes:
      - /docker/monapp/data:/app/data   # bind mount : reste writable malgré read_only
    env_file: .env
    networks: [monapp]
    # backend pur : PAS de bloc ports: (accessible via le réseau interne seulement)

  frontend:
    image: ghcr.io/actarus314/mon-image-frontend:${IMAGE_TAG:-latest}
    restart: unless-stopped
    ports:
      - "127.0.0.1:${PORT:-3000}:8080"
    read_only: true
    tmpfs:                        # nginx-unprivileged écrit dans ces 3 chemins
      - /tmp
      - /var/cache/nginx
      - /var/run
    cap_drop: [ALL]
    cap_add: [CHOWN, SETGID, SETUID]   # strict minimum nginx-unprivileged (init puis drop)
    security_opt:
      - no-new-privileges:true
    pids_limit: 128
    mem_limit: 128m
    depends_on: [backend]
    networks: [monapp]

networks:
  monapp:
    driver: bridge
```

### Directives clés

- **`cap_drop: [ALL]`** : supprime toutes les capabilities Linux (la plus impactante). `cap_add` au strict minimum, cas par cas — nginx-unprivileged : `CHOWN`/`SETGID`/`SETUID` (init puis drop vers non-root) ; Caddy Alpine (`setcap +ep` sur le binaire) : `NET_BIND_SERVICE` même sur port haut.
- **`read_only: true`** : FS du container en lecture seule (empêche un payload déposé). Les **volumes montés restent writable** (cas SQLite/fichiers). Compléter avec `tmpfs` pour les chemins d'écriture de l'image (backend : `/tmp` ; nginx-unprivileged : + `/var/cache/nginx` + `/var/run`). Crash au démarrage → souvent un chemin `tmpfs` manquant.
- **`no-new-privileges: true`** : bloque l'escalade via binaires setuid/setgid de l'image.
- **`pids_limit` / `mem_limit`** : anti fork-bomb / anti-OOM hôte. Indicatif : backend 256 pids / 512m, frontend léger 128 / 128m.
- **`user:` (si utilisé)** : toujours **UID:GID numériques** (l'image n'a pas le `/etc/passwd` de l'hôte). Images à process manager embarqué (PM2, supervisord) : **pas de `user:`**, gérer via `chown` du volume côté hôte.

### Cas particuliers

- **Backend pur (sans port exposé)** : pas de bloc `ports:` du tout ; accessible uniquement via le réseau Docker interne par les autres containers de la stack.
- **Bind mount SQLite / fichiers** : `read_only` ne touche pas les volumes montés → le volume reste writable. En `root:root` durci, root écrit le bind mount → **évite le piège dEURO** (§12 : distroless `:nonroot` UID 65532 → perte d'écriture silencieuse `SQLITE_READONLY_DIRECTORY`). Garder une **sonde d'écriture au boot** (échec bruyant + exit non-zéro) en defense-in-depth. Sous `read_only`, un écrivain SQLite pose `PRAGMA temp_store=MEMORY` (+ `SQLITE_TMPDIR=/tmp`).
- **Process manager embarqué (PM2/supervisord)** : démarre root et gère son propre drop → pas de `user:`.

### Le runtime ne doit PAS embarquer son gestionnaire de paquets

**`npm` est un outil de BUILD.** Le laisser dans l'image de runtime y expédie **tout son arbre de dépendances — et ses CVE**.
Un scan Trivy a déjà trouvé des CVE **CRITICAL/HIGH** (`pacote`, `picomatch`, bundlés dans `npm`) sur une app qui n'a **aucune dépendance de production**. Les vulnérabilités ne venaient pas du code, mais de l'**outil qu'on avait oublié de retirer**.

```dockerfile
RUN npm ci --omit=dev \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /root/.npm
```
Scan **vert** après cette seule ligne. *(Une image `distroless` en second étage produit le même effet — plus lourde à maintenir pour un gain identique ici.)*

### Avant prod

- **Scan CVE** : `trivy image <nom-image>:<tag>` avant tout déploiement — **et en gate CI** (§17), pas seulement à la main : scanner au déploiement, c'est scanner trop tard.
- **Checklist d'audit par service** : `cap_drop:[ALL]` · `read_only:true` · `tmpfs` couvre toutes les écritures · `no-new-privileges:true` · `pids_limit` · `mem_limit` · ports en `127.0.0.1` si interne · réseau bridge dédié · pas de `--privileged` · pas de `version:`.

---

## 15. README — double cible : dev + vitrine

Le `README.md` sert **deux publics à la fois**, sans choisir :
- **le dev** qui clone/forke/contribue — install, run, structure, contribution ;
- **la vitrine** — une page honnête qui donne envie, sans survendre.

Léché, concis, **zéro salade**. Bilingue **anglais puis français**, séparés par `---`.

**Structure type** :
- **Titre** = `Nom — sous-titre qui dit ce que c'est` (pas juste le nom).
- **Accroche** orientée le problème réel de l'utilisateur, honnête (pas de superlatif creux).
- **Disclaimer** en tête (blockquote ⚠️) si l'outil est tiers/non-officiel ou touche des fonds.
- **Captures** thème clair + sombre via `<picture>` + `prefers-color-scheme` ; l'autre thème replié en `<details>`.
- **« Why this exists / Pourquoi »** avant le *how*.
- Sections courtes : Quick start, Structure, License.
- **Ton** : factuel, chiffré, honnête sur les limites — et jamais de 2ᵉ personne (§1).

Modèle : `templates/repo/README.md`. Exemple vivant complet : le README de `rozo-bridge`.

## 16. Docs de vie du projet — **un PRINCIPE, pas des fichiers imposés**

> 🔴 **Ce template initialise TOUT projet — y compris ceux qui seront ensuite conduits par un système de gestion tiers** (GSD, superpowers, ou autre).
> **Lui imposer nos fichiers de suivi les mettrait en COLLISION avec le sien** (`.planning/` & co.).
> **Deux systèmes de suivi concurrents dans un projet, c'est zéro système tenu.**

### Le PRINCIPE — vrai quel que soit l'outil qui le porte

| Rôle | La règle |
|---|---|
| **Un doc de REPRISE** | **CONCIS.** Il est lu et édité **très souvent** → il doit rester court. Il **RENVOIE** au détail *(ADR, plans, notes)*, **il ne l'absorbe pas**. |
| **Un BACKLOG / TODO** | **BREF.** Il dit ce qu'on a prévu, et **POINTE** vers un plan détaillé le cas échéant. |
| **Le livré est PURGÉ** | Un backlog qui accumule le fait n'est plus un backlog : **c'est un journal**. |

**Objectif** : qu'un humain **ou** une IA rouvrant le projet à 6 mois s'y retrouve **sans lire un pavé**.

> **C'est la même règle que `repo/docs/` vs `workspace/` dans le template lui-même** : *le document qu'on lit souvent reste court et renvoie ; le détail vit ailleurs.* Un doc de suivi qu'on ne relit plus ne suit plus rien.
> **La règle générale, et le fait que l'outil de suivi soit un DÉFAUT remplaçable : `METHODE.md`.**

### L'IMPLÉMENTATION — remplaçable

**Par défaut**, `init-project.sh` pose dans `workspace/docs/` (jamais poussé) :
- **`SUIVI.md`** — la reprise à froid *(état, environnements, historique, décisions de projet, pièges connus)* ;
- **`BACKLOG.md`** — le travail courant *(en cours / à faire / notes ouvertes / idées)*.

**Ces deux fichiers sont le DÉFAUT, pas un dogme.**
→ **`init-project.sh --no-lifecycle-docs`** les omet, **quand un autre système prend le relais**.

> ⚠️ **AVANT de créer quoi que ce soit pour piloter un projet** — suivi, backlog, planification, reprise de contexte — **VÉRIFIER CE QUI EXISTE DÉJÀ** : skills et agents installés *(une centaine, dont tout **GSD** : `gsd-progress`, `gsd-resume-work`, `gsd-pause-work`, `gsd-review-backlog`, `gsd-capture`…)*, plugins, marketplace, fonctionnalités natives.
> **Si aucun système n'est explicitement en usage sur ce projet, le chercher AVANT d'en fabriquer un.** *(`find-skills` sert exactement à ça.)*
> **Ne construire du custom qu'à défaut** — et le dire.

### Les décisions structurantes → `repo/docs/adr/`
**Versionnées, immuables.** Un ADR n'est pas édité quand la décision change : **on en écrit un nouveau qui supersède l'ancien**. Ce qui compte, c'est de préserver le **pourquoi** — que le code ne peut pas exprimer.

### Ce qui est VERSIONNÉ (dans `repo/`), et pourquoi

| Fichier | Rôle | Pourquoi il est versionné |
|---|---|---|
| **`AGENTS.md`** | Instructions projet **pour tout agent** : commandes, structure, branches, conventions, contrôles, ne-pas-toucher | **Standard réel** ([agents.md](https://agents.md), passé à la Linux Foundation fin 2025, lu par 30+ agents : Cursor, Copilot, Gemini CLI…). **`CLAUDE.md` l'importe via `@AGENTS.md`** et ne garde que le **perso** (pointeurs `workspace/`, secrets, auth) → **une seule source, aucun drift**. |
| **`CHANGELOG.md`** | Ce qui a changé **pour un utilisateur** — format [Keep a Changelog](https://keepachangelog.com), **lien inline** par version (`## [X.Y.Z](…/releases/tag/vX.Y.Z)`) | La Release GitHub porte la liste **auto-générée des PR** ; le CHANGELOG porte le **sens**. *(Les sources jugent ce doublon superflu en solo — maintenu malgré tout, pour le sens qu'il apporte au-delà de la liste des PR.)* |
| **`docs/adr/`** | Une fiche par décision **structurante** (stack, schéma, frontière) — format [Nygard](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions) | Préserve le **pourquoi**, que le code ne dit jamais. Validé même en solo (coût quasi nul). **Immuable** : une décision périmée n'est pas éditée, elle est *superseded*. |

**Écartés délibérément** (théâtre en solo, vérifié) : `llms.txt` (mode SEO, pas un standard) · `SUPPORT.md` · `GOVERNANCE.md` · `CITATION.cff` · `ROADMAP.md` (le `BACKLOG.md` le couvre).

**Autres defaults** : i18n eng/fr avec **dictionnaire séparé** (jamais de ternaires inline) + parité en CI.

## 17. Configuration du repo GitHub

Tout le spectre config/maintenance d'un repo public — contrôles sécu/code, **matrice PAT à deux étages** (récurrent autonome / admin one-shot), OpenSSF, scriptable vs UI, checklist nouveau repo — est dans **`github-repo-config.md`** (à côté de ce fichier). C'est du **one-shot** : réglé à la création via `configure-repo.sh`, puis oublié.

En bref : **CodeQL en *default setup* natif** · Dependabot · secret scanning + push protection · **private vulnerability reporting** · ruleset `main` (+ `develop` si elle existe) · **ruleset sur les tags** · **immutable releases** · actions tierces pinnées SHA · `permissions:` minimal. Le PAT de l'assistant gère les alertes en autonomie, **sans jamais toucher à Administration**.

> 🔎 **`immutable releases` est scriptable, pas seulement via l'UI.** L'endpoint `PUT /repos/{owner}/{repo}/immutable-releases` existe et relève d'`Administration: write`, **déjà** dans la recette du PAT admin : **rien à ajouter, tout à automatiser**.

### 🔴 CodeQL : **default setup**, et surtout PAS un `codeql.yml` committé

**Il n'y a plus de `codeql.yml` dans le template.** `configure-repo.sh` active le **default setup** de GitHub par API *(`PATCH /repos/{o}/{r}/code-scanning/default-setup`, `Administration: write` — déjà dans la recette du PAT admin)*.

**Pourquoi le natif l'emporte ici — et ce n'est pas une question de goût :**

| | notre ancien `codeql.yml` | **default setup** |
|---|---|---|
| Langages analysés | **UN SEUL, codé en dur** | **tous**, **détectés automatiquement** |
| Un langage apparaît dans le repo | **ignoré à vie** *(personne ne pense à éditer le YAML)* | **analysé tout seul** — [GitHub met la config à jour](https://github.blog/changelog/2023-06-26-code-scanning-default-setup-automatically-updates-when-the-languages-in-the-repository-change/) |
| Scans planifiés | un `cron` qu'on maintient | **inclus** |
| Maintenance | **la nôtre** | **celle de GitHub** |

> 🔴 **Ce n'était pas une préférence, c'était un TROU.** Prouvé sur `test004` *(2026-07-14)* : notre `codeql.yml` ne déclarait que `javascript-typescript`. Le default setup, lui, a trouvé **`actions` EN PLUS** — autrement dit **le template n'analysait pas ses PROPRES workflows**. Le custom était du natif **dégradé**, et il dégradait un **contrôle de sécurité**.

**Ce que le default setup NE sait pas faire** *(la porte de sortie, si un projet en a un jour besoin)* : query packs personnalisés · `paths-ignore` · étapes de build sur mesure · upload depuis une CI externe.
→ **Alors seulement**, revenir à un `codeql.yml` committé — **et y déclarer TOUS les langages du repo**, à la main, pour de bon.

**Conséquences à ne pas manquer :**
- **Repo PRIVÉ (Free)** : le default setup est **indisponible** *(GHAS requis)* — exactement comme l'était le workflow. **Rien ne change** : `Semgrep` + `osv-scanner` restent la parade *(voir plus bas)*.
- **CodeQL ne « se réveille » plus tout seul au flip** : c'est **le rejeu de `configure-repo.sh`** qui l'active — et ce rejeu est **déjà obligatoire** dans la procédure de bascule *(§18)*. Aucun geste nouveau.
- Un repo **legacy** portant encore un `codeql.yml` : l'activation le passe en **`disabled_manually`** — GitHub refuse les deux modes à la fois. Le script **le dit** au lieu de le faire en silence. **Supprimer alors le fichier : un workflow orphelin est un contrôle que plus personne ne lit.**
- Le check-run **garde le nom `CodeQL`** : la règle de ruleset `code_scanning` *(`tool: CodeQL`)* est **inchangée**, et continue de bloquer les PR.

### Contrôles recommandés (bonnes pratiques du secteur)

| Contrôle | Ce qu'il empêche | Où |
|---|---|---|
| **Ruleset sur les tags `v*`** (`deletion`, `update`) | Qu'un tag de release soit **déplacé ou supprimé**. **Sans lui, le pin de version du §13 ne garantit RIEN** : la prod épingle `X.Y.Z` en croyant figer un artefact, alors que le tag peut pointer ailleurs demain. | `configure-repo.sh` |
| **Immutable releases** *(GA 28/10/2025)* | Que les **assets** d'une release publiée soient **remplacés**. C'est le pendant du ruleset `tags` : celui-ci fige le **tag**, celui-là fige le **contenu**. Sans les deux, le pin du §13 se contourne **sans toucher au tag** — on republie un autre binaire sous le même. **NON RÉTROACTIF : « immutability will only apply to future releases » → posé AVANT la v1.** | `configure-repo.sh` *(à la bascule publique)* |
| **Private vulnerability reporting** | Qu'un chercheur externe n'ait **aucun moyen de signaler en privé** — et publie donc la faille en issue publique. **Sans lui, le lien de `SECURITY.md` est MORT.** | `configure-repo.sh` |
| **`dependency-review-action`** (PR) | Qu'une dépendance vulnérable ou mal licenciée **entre**. Dependabot n'alerte qu'**APRÈS** le merge : les deux sont complémentaires, pas redondants. | `ci-node.yml` |
| **`actionlint` + `zizmor`** (PR) | Que **les workflows eux-mêmes** soient le trou : un `${{ }}` interpolé dans un `run:` est une **injection de shell**. | `ci-*.yml` |
| **`persist-credentials: false`** | Que le `GITHUB_TOKEN` **traîne dans `.git/config`** et fuite par un artefact (audit `artipacked`). | tous les `checkout` |
| **`default_workflow_permissions: read`** | Qu'un workflow **futur**, écrit sans bloc `permissions:`, hérite d'un `GITHUB_TOKEN` **en écriture**. Nos workflows le déclarent tous — c'est un filet, pas un gain immédiat. | `configure-repo.sh` |
| **Dependabot `groups`** | Le **bruit** : minor + patch groupés en **une** PR par écosystème (5 PR d'un coup constatées sans ça). Les **majors restent isolés** — un major peut casser, il mérite d'être regardé seul. | `dependabot.yml` |
| **Trivy** sur l'image (PR) — *capacité **`artefact`*** | Qu'une image portant une CVE **CRITICAL/HIGH** atteigne `main`. Scanner **au déploiement est trop tard** : l'image est déjà taguée et la prod l'épingle. Le job **`build-check` est un check REQUIS** — sinon le scan est **décoratif**. | `docker-publish.yml` |

### Qui met à jour les outils épinglés — la frontière Dependabot / Renovate

**Le pin protège de la supply chain ET pourrit la détection.** Les deux sont vrais en même temps : un `gitleaks` gelé rate les nouveaux formats de secrets, un `semgrep` gelé n'a jamais les nouvelles règles. **Un scanner de sécurité figé finit par rater ce qu'il est censé trouver.**

⚠️ **Dependabot ne lit JAMAIS une commande shell.** Il ne voit que les `uses:`, `package.json`, `FROM` et les fichiers de dépendances déclarés. Un outil `curl`-é dans un `run:`, ou un `pip install X==Y` inline, **n'est surveillé par personne**.

| Quoi | Qui le bumpe | Comment |
|---|---|---|
| `uses:` (actions) · npm · docker (`FROM`) | **Dependabot** | écosystèmes de `dependabot.yml` |
| **`zizmor` · `semgrep`** (Python) | **Dependabot** | → sortis du YAML vers **`requirements-ci.txt`**, écosystème `pip` : **natif, zéro custom** |
| **`gitleaks` · `actionlint` · `osv-scanner` · `trivy`** (binaires + SHA256) | **Renovate** | `.github/renovate.json` — datasource **`github-release-attachments`** : lit le `SHA256SUMS` de la release et bumpe **version ET checksum dans la même PR** |

> 🔴 **`"enabledManagers": ["custom.regex"]` — NE PAS RETIRER.** Sans cette ligne, Renovate ouvrirait **aussi** des PR pour npm, docker, pip et les actions — que Dependabot gère déjà : **toutes les PR en double**. La frontière est nette : *Dependabot = les écosystèmes déclarés · Renovate = les binaires que Dependabot ne peut pas voir.*

**Filet** : si Renovate proposait un checksum erroné, le `sha256sum -c` **fait échouer la CI** — bruyamment, jamais en silence. Une PR rouge se ferme ; elle ne peut pas empoisonner `main`.

**Prérequis** : l'app **Renovate** doit être installée sur le repo (UI GitHub, gratuite). Sans elle, `renovate.json` est **inerte** — et les 4 binaires gèlent sans que rien ne le signale.

> **Politique de pin — `.github/zizmor.yml`** : SHA complet obligatoire pour **toute action tierce** ; **tag majeur toléré pour `actions/*` et `github/*`** (les compromettre = compromettre GitHub). Ce n'est pas de la coquetterie : en **mars 2026, 75 des 76 tags de `aquasecurity/trivy-action` ont été force-pushés**. Un tag est mutable ; un SHA ne l'est pas.

**Écartés, après examen** : attestations SLSA (personne d'autre ne consomme les images → on signerait dans le vide) · OpenSSF Scorecard (mesure la conformité *process*, score gamable) · CODEOWNERS et merge queue (multi-contributeurs).

---

## 18. Matrice des contrôles — quoi, où, quand, par qui

> Principe : **chaque défaut est attrapé au plus tôt**, et chaque étage rattrape ce que le précédent a laissé passer.

| Étage | Contrôles | Quand | Par qui |
|---|---|---|---|
| **Pre-commit** *(local)* | **gitleaks** (fichiers stagés) — **et rien d'autre** : pas de lint. *Aucun linter n'est universel aux deux toolchains (static n'a pas de toolchain, node dépend du projet) : imposer un `eslint` que la moitié des projets n'ont pas ferait échouer le hook au premier commit. Le lint appartient au projet, pas au template.* | à chaque commit | poste de dev |
| **Push** *(serveur)* | **secret scanning push protection** | à chaque push | GitHub |
| **PR** *(CI)* | **gitleaks** (historique **complet**) · **actionlint** + **zizmor** (les workflows) · **Semgrep** + **osv-scanner** *(les seuls qui tournent en PRIVÉ — voir ci-dessous)* · **CodeQL** *(public seulement)* · tests + typecheck + `npm audit` + **dependency-review** *(public seulement)* + **Trivy sur l'image** (*capacité `artefact`* — **pas** « node » : un site `static` qui publie une image l'a aussi) · syntax-check (toolchain `static`) | à chaque PR | GitHub Actions |
| **Serveur** | ruleset `main` (+ `develop` si elle existe) : PR obligatoire, **checks requis (`checks` + CodeQL + `build-check` si image Docker)**, no force-push/deletion · **ruleset tags `v*`** (ni suppression ni déplacement) **+ immutable releases** (ni remplacement des assets) — *les deux, sinon le pin du §13 se contourne* · secret scanning · **private vulnerability reporting** | en continu | GitHub |
| **Planifié** | CodeQL · Dependabot alerts + security updates + version updates | hebdomadaire | GitHub |
| **Rotation** | PAT d'écriture — **alerte J-14** dans `.envrc` (§5) | tous les 90 j | Claude alerte · Romain régénère |

> **Trois barrières bloquent réellement, et elles sont redondantes à dessein** : le **hook** attrape tôt mais est *local*, contournable (`--no-verify`) et **absent d'un clone frais** ; la **push protection** n'attrape que les patterns GitHub *connus* ; la **CI** scanne tout l'historique et **garantit** — c'est la seule que personne ne peut sauter, parce que le ruleset l'exige avant merge.

### En privé, RIEN n'est exigé — la discipline est le seul filet, donc elle est OUTILLÉE

Sur un repo privé/Free, **il n'y a aucun ruleset**. Tous les contrôles **tournent**, **aucun n'est requis** : GitHub accepterait un `git push` **direct sur `main`**, et une PR **rouge** peut être mergée. La couverture est bonne ; c'est **l'exécution forcée** qui manque.

> ⚠️ **Une discipline qui n'est qu'écrite n'existe pas.** Elle est donc portée par des outils partout où c'est possible, et réduite à une seule règle humaine là où ça ne l'est pas.

| Ce qu'il faut tenir | Comment c'est tenu | Contournable ? |
|---|---|---|
| Pas de secret commité | hook **`pre-commit`** (`gitleaks`) | `--no-verify` → **la CI rejoue sur l'historique complet** |
| **Pas de push direct sur `main`/`develop`** | hook **`pre-push`** — *le substitut du ruleset absent* | `--no-verify` (**une décision, pas un accident**) |
| **Ne jamais merger une PR rouge** | ❗ **règle humaine** — vérifier que **tous les workflows attendus** sont `completed / success` *(commande ci-dessous — surtout **pas** `gh pr checks`)* | rien ne l'empêche côté serveur |

> 🔴 **`gh pr checks <n>` est INUTILISABLE avec le PAT du standard — la règle était écrite partout, et inapplicable partout.**
> Elle lit `statusCheckRollup`, qui exige la permission **`Checks`**. Cette permission est **documentée** par GitHub mais **absente de l'UI** des PAT fine-grained : elle **ne peut pas être accordée** *(github/community#129512, cli/cli#12597)*. Résultat : `Resource not accessible by personal access token`. *(`gh pr view <n>` tout court échoue pour la même raison.)*
> **Rien à ajouter au PAT** — la commande ci-dessous n'a besoin que d'`Actions: read`, déjà dans la matrice (§5).
>
> ```bash
> sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)   # --json cible → plus de rollup demandé
> gh run list --commit "$sha"
> ```
>
> **VERT ⇔ TOUS les workflows ATTENDUS sont `completed / success`** : `CI`, **+ `Publish image`** si `docker-publish.yml` existe — *le même ensemble que les checks requis du ruleset, dérivé de la même façon (la présence du workflow)*, pour que la barrière humaine et le serveur qui la remplacera au flip disent exactement la même chose.
> ⚠️ **Un workflow ABSENT n'est PAS un vert.** GitHub enregistre les workflows **un par un** : pendant quelques secondes après un push, `CI` peut être `success` alors que `Publish image` n'est pas encore créé. Se contenter de « aucun échec » déclare alors la PR mergeable **en ratant un check** — *vérifié sur test003, faux vert reproduit à t+10 s*. **« Rien de rouge » ≠ « tout est vert ».**

Le `pre-push` **laisse passer la création** d'une branche (sinon le 1ᵉʳ push d'un repo neuf serait impossible) et **reste actif en public** — le serveur refuse alors le même push, mais le message local est bien plus clair. *Défense en profondeur.*

**Le seul point réellement humain est le merge d'une PR rouge** : aucun hook ne peut l'intercepter, le merge se joue côté serveur. → écrit dans **`AGENTS.md`** (donc lu par les agents) et dans `CONTRIBUTING.md`.
**Tout cela s'efface au passage en public** : les rulesets *exigent* alors les checks, et le serveur applique ce que la discipline seule retenait.

### Le trou de la phase privée — et pourquoi Semgrep + osv-scanner existent

**Un repo passe toute sa jeunesse en privé.** Or en privé/Free, **CodeQL et `dependency-review` sont indisponibles** (ils exigent GHAS). Sans parade, **le code n'est jamais analysé statiquement** jusqu'au jour du flip — et CodeQL déverse alors **tout l'arriéré d'un coup**.

> 🚫 **Impasse vérifiée : CodeQL est INTERDIT sur du code privé — par LICENCE, pas par une limite technique.** La licence du CodeQL CLI exclut *« any codebase that is not an Open Source Codebase (e.g., code in a private repo) »* sauf licence **GHAS payante** (~30 $/committer/mois, plan Team). **Aucun contournement légal**, même en local. → **GHAS écarté** : on paierait pour un **état transitoire**, alors que tout devient **gratuit** dès que le repo est public.

| Outil | En privé | Rôle | Limite à connaître |
|---|---|---|---|
| **Semgrep OSS** | ✅ gratuit, **sans compte ni token** | Analyse statique — le **recouvrement partiel mais réel** avec CodeQL | **Fichier par fichier** : aucune analyse inter-fichiers. Il **PRÉCÈDE** CodeQL, il ne le remplace **pas**. |
| **osv-scanner** | ✅ gratuit (Apache-2.0) | **L'équivalent de `dependency-review`, qui lui marche en privé** | Base OSV : pas de contrôle de **licence** → `dependency-review` reste utile en public. |

**Gardés en PERMANENCE**, pas seulement en privé : Semgrep attrape ce que CodeQL rate, et **la phase privée est celle où l'on écrit le plus de code** — donc celle où l'on veut *plus* de signal, pas moins.

⚠️ **`--exclude=.github` sur Semgrep, et c'est délibéré** : ses règles sur les workflows **contredisent** notre politique de pin (SHA pour le tiers, tag majeur toléré pour `actions/*` — cf. `.github/zizmor.yml`). Sans cette exclusion, **tout scaffold neuf échoue dès sa 1ʳᵉ PR**. Les workflows ont **déjà** leurs linters dédiés (`actionlint` + `zizmor`). **Un périmètre par outil, aucun recouvrement.**

**Ce que ça ne résout pas** : le 1ᵉʳ passage de CodeQL au flip reste **une étape de triage assumée** — mais sur un code **déjà défriché**, c'est un *résidu*, plus une avalanche.

### La matrice n'est PAS uniforme — elle dépend de la visibilité

| Étage | Repo **public** (Free) | Repo **privé** (Free) |
|---|---|---|
| Pre-commit | ✅ | ✅ |
| PR (CI) | ✅ | ✅ |
| Serveur (ruleset, secret scanning) | ✅ | ❌ **indisponible** |
| Planifié — CodeQL | ✅ | ❌ **indisponible** |
| Planifié — Dependabot | ✅ | ✅ *(gratuit sur privé)* |

**Conséquence, à ne pas manquer** : sur un repo **privé**, les étages *serveur* et *CodeQL* sont **vides**. Le **pre-commit devient le seul filet anti-secret** — `gitleaks` n'y est pas un confort, c'est la seule barrière. C'est ce qui fait du pre-commit le **socle**, et non un raffinement.

Un repo privé gagne les trois étages manquants **d'un coup** en passant public → c'est le moment de rejouer `configure-repo.sh` (§10, étape 7), **après** un `gitleaks detect` sur l'**historique complet** (§17) : au flip de visibilité, un secret enfoui dans un vieux commit devient public.

### Mise en œuvre
- **Hook** : `repo/.githooks/pre-commit` — **versionné** (donc partagé), activé par `git config core.hooksPath .githooks` (posé par `init-project.sh` ; **un clone frais doit le reposer**).
  Il lance `gitleaks git --staged --redact` : **exit 1 → commit bloqué**, silencieux si tout va bien. **Échec dur si gitleaks est absent** — un scanner manquant ne doit jamais ressembler à un scan propre.
- **CI** : **binaire `gitleaks` épinglé + checksum vérifié** (⚠️ **PAS `gitleaks-action`** : elle exige une **licence** sur un repo d'**ORGANISATION** → la CI serait **rouge d'office**), avec `fetch-depth: 0` → scan de l'**historique complet**, sur les **deux** toolchains.

### Pourquoi le pre-commit ne suffit pas seul
Un hook local est **contournable** (`git commit --no-verify`) et n'existe que sur la machine qui l'a installé. D'où le doublon **gitleaks en CI** : le hook attrape tôt, la CI **garantit**. Les deux, pas l'un ou l'autre.

### ⚠ Auditer un historique : scanner `main`, PAS la branche courante
`gitleaks git` scanne l'historique accessible depuis **HEAD**. Lancé depuis une branche de travail, il ne dit **rien** de l'état de `main` — les deux historiques divergent dès qu'ils ont des commits propres.

**Procédure correcte** — depuis un worktree détaché sur la cible, pour ne pas perturber l'arbre de travail :
```bash
git fetch origin main
git worktree add --detach /tmp/scan origin/main
( cd /tmp/scan && gitleaks git --no-banner --redact )
git worktree remove --force /tmp/scan
```
**Avant un passage privé → public** (§17), c'est **toutes les refs** qu'il faut couvrir, pas seulement `main` : un secret dans une vieille branche poussée devient public lui aussi.

### Passage privé → public — **étape normale du flux**, pas un cas particulier

**C'est le chemin nominal** (§10) : tout repo naît privé et bascule public. Un repo privé en Free n'a **ni ruleset, ni CodeQL, ni secret scanning** — il les gagne **tous d'un coup** au flip.

> ⚠️ **Le flip est le moment le plus dangereux du cycle de vie d'un repo** : **tout l'historique devient public d'un seul coup**, y compris un secret enfoui dans un commit vieux de six mois — et il aura été poussé pendant la phase où **aucun secret scanning côté serveur n'existait**. D'où l'étape 1, non négociable.

| # | Qui | Geste |
|---|---|---|
| 1 | Claude | **`gitleaks` sur TOUTES les refs**, pas seulement `main` — un secret dans une vieille branche poussée devient public lui aussi. Depuis un **worktree détaché** (§18). |
| 2 | Romain | Flipper la visibilité (UI). |
| 3 | Romain | **Rejouer** `./configure-repo.sh <owner>/<repo> '' '<description>' '<topics>'` (PAT admin **éphémère**) → ruleset `main`, secret scanning + push protection, Dependabot, **immutable releases**, description, **topics**, **ACTIVATION DE CODEQL** *(default setup)*, et la **méthode de merge selon la capacité `staging`** (squash seul ; **+ merge commit si `develop` existe** — squash seul est incompatible avec une branche de staging, §12). Le script est **idempotent** : rejouable sans dégât. |
| 4 | — | **Rien à faire pour les workflows.** `pages.yml` porte `if: github.event.repository.visibility != 'private'` : il est **`skipped`** en privé et **se réveille seul** au flip. ⚠️ **CodeQL, lui, n'est PLUS un workflow** *(plus de `codeql.yml` — §17)* : c'est **l'étape 3 qui l'active**, en *default setup*. Le script **attend sa 1ʳᵉ analyse** avant de poser la règle `code_scanning` — sans quoi `main` resterait non gardée. |
| 5 | **Romain** | **Repo d'ORG — SYSTÉMATIQUE, jamais une exception** : Settings → **Moderation options** → **Reported content** → « Prior contributors and collaborators ». **Aucune API** (ni REST ni GraphQL). GitHub applique ce défaut aux repos **créés publics** — donc **jamais aux nôtres**, qui naissent privés. Sans ce clic, le community health **plafonne à 87 %**. `configure-repo.sh` le signale en fin de course. |
| 6 | Claude | Vérifier en lecture : community health **100 %** · CodeQL **vert** · ruleset **actif** · secret scanning **on**. |
| 7 | — | **Rien à faire pour la règle `code_scanning`** : à l'étape 3, le script **active CodeQL, ATTEND sa 1ʳᵉ analyse, PUIS pose la règle** — le tout en une seule exécution. *(Sans cette attente, il activerait CodeQL, lirait « 0 analyse », et ne poserait pas la règle : **`main` resterait NON PROTÉGÉE** jusqu'à ce que quelqu'un pense à rejouer le script — un trou ouvert par le script lui-même.)* |

> **Pourquoi les workflows s'auto-gèrent au lieu d'être ajoutés au flip** : une procédure manuelle est un coût récurrent et *oubliable*. Un job qui échoue à chaque run sur un repo privé rend la CI rouge en permanence — et **une CI toujours rouge n'est plus lue**. La condition est écrite `!= 'private'` (jamais `== 'public'`) : si le champ venait à manquer du payload, le job **tourne** (du bruit) au lieu de **désactiver silencieusement un contrôle de sécurité**.
>
> ⚠️ **CodeQL faisait exception à ce principe, et c'était le mauvais arbitrage.** Son `codeql.yml` s'auto-gérait, oui — mais au prix d'**un seul langage figé, que personne ne mettait jamais à jour**. On préférait l'auto-gestion d'un contrôle *incomplet* à un geste scripté d'un contrôle *complet*. Le geste, de toute façon, **existait déjà** : le rejeu de `configure-repo.sh` est obligatoire au flip. **On n'a rien ajouté — on a juste cessé de rater des langages.** *(§17.)*

### Acquérir une CAPACITÉ sur un repo déjà vivant

Le repo garde tout le reste : on ne change pas de catégorie, on **ACQUIERT une capacité**. Un site Pages qui se met à publier une image **reste** un site Pages.

`init-project.sh` pose les capacités **à la création**. Ici le repo a déjà un historique, des rulesets et des checks requis : on ne rejoue pas le générateur, on **ajoute** — dans le bon ordre.

> ⚠️ **L'ORDRE EST LE PIÈGE, et il est contre-intuitif.** `configure-repo.sh` rend `build-check` **requis** dès qu'il voit `docker-publish.yml` sur `main`. Rejoué **avant** que le workflow y soit, il exige un check **qui ne rapportera jamais** : toute PR reste bloquée à jamais sur *« Expected — waiting for status »* — **y compris celle qui apporte le workflow**. Le repo **se verrouille lui-même**.
> **→ Le workflow doit atteindre `main` AVANT que le script ne l'exige.** Cette règle vaut pour toute capacité qui ajoute un **check requis**.

#### Acquérir `--artefact` — « je veux que d'autres puissent auto-héberger mon projet »

*Le cas `rozo-bridge` : une page Pages que l'on packagera en image pour que des tiers la déploient et suivent les updates. **Pages reste**, et il n'y a **aucun `develop` à créer** — il n'existe aucun host à valider.*

| # | Qui | Geste |
|---|---|---|
| 1 | Claude | **Une seule PR** : `Dockerfile` + `docker-publish.yml` (image substituée : `ghcr.io/<owner>/<repo>`). Elle **passe** : `build-check` n'est **pas encore** requis.<br>**Page statique → `FROM nginx:alpine`** *(un serveur web, pas une toolchain — §14)*, **SUIVI DE `RUN apk upgrade --no-cache`.**<br>🔴 **Cette ligne n'est PAS cosmétique.** `nginx:alpine` est **en retard sur les paquets Alpine** : au 14/07/2026, l'image courante portait **8 CVE HIGH** *(c-ares, curl/libcurl, libexpat)* — **toutes DÉJÀ corrigées en amont**. Trivy tourne avec `--ignore-unfixed` : il les remonte donc **toutes**, et **`build-check` part ROUGE**. **Le scanner du template refuse alors l'image que le template recommande.** *(Mesuré sur test005 — C2.)* |
| 2 | Claude | Dans la **même** PR : ajouter l'écosystème **`docker`** à `dependabot.yml`. ⚠️ **Pas optionnel** — sans lui l'**image de base** n'est **jamais** bumpée, et Trivy bloquerait les PR sur une CVE de l'image **sans que rien ne propose le correctif** : le contrôle détecte, personne ne répare. |
| 3 | — | **Ne PAS toucher au bloc `## Branching`** ni créer `develop` : sans host à valider, ce serait un **rituel vide** (§12). |
| 4 | Romain | Merger. `main` porte désormais `docker-publish.yml` — la condition de l'étape 5 est remplie. |
| 5 | Romain | **Rejouer** `configure-repo.sh` → il détecte le workflow, exige **`build-check`**, pose le **ruleset `tags`** et les **immutable releases**, et **vérifie que l'image est tirable anonymement**. |
| 6 | **Romain** | **VÉRIFIER que le package ghcr est tirable anonymement** — `configure-repo.sh` le teste. Sur un compte **perso** (repo public), il l'est **d'office** ; sur une **ORG**, il peut être **PRIVÉ** → `docker pull` anonyme = **403**, et **personne ne peut auto-héberger**. **Ne rendre public que si le test échoue** *(UI, aucune API)*. |
| 7 | Romain | **Avant la v1** : les immutable releases sont **non rétroactives**. Après, il est trop tard. |
| 8 | Claude | Documenter l'auto-hébergement dans le README (`docker run ghcr.io/<owner>/<repo>:X.Y.Z`) — **avec un tag épinglé, jamais `:latest`** (§13). |

#### Acquérir `--staging` — « un host apparaît, je veux le valider avant la prod »

| # | Qui | Geste |
|---|---|---|
| 1 | Claude | **Une PR** : réécrire le bloc `## Branching` de **`CONTRIBUTING.md` ET `AGENTS.md`** en 3 étages (§12) — les deux publient encore GitHub Flow. |
| 2 | Claude | Créer et pousser `develop` : `git push -u origin develop` *(le hook `pre-push` laisse passer la **création**)*. |
| 3 | Romain | **Rejouer** `configure-repo.sh` → il détecte `develop`, pose son **ruleset**, et **autorise le merge commit** sur `main` (squash seul est **incompatible** avec une branche de staging). |
| 4 | Claude | `docker-publish.yml` écoute déjà les PR vers `main` **et** `develop` — rien à faire. *(Sans ça, une PR vers `develop` resterait bloquée à jamais.)* |

#### Acquérir / retirer `--pages`

**Acquérir** : copier `pages.yml`, y renseigner le `<web-dir>`, et créer le site *(`configure-repo.sh` le fait — `Pages: write`)*. Aucun check requis n'est ajouté → **aucun risque de verrouillage**, l'ordre est libre.
**Retirer** : supprimer `pages.yml`. Ne **jamais** le laisser tourner « au cas où » — **un workflow orphelin est un contrôle que plus personne ne lit**.

#### Retirer une capacité — le sens inverse

Il ne fait que **retirer** des contrôles : aucun risque de verrouillage… **sauf un**, symétrique de l'étape 1.
⚠️ **Retirer `build-check` des checks requis AVANT de supprimer `docker-publish.yml`.** Dans l'autre sens, le check reste exigé alors que plus rien ne le produit → **toute PR est bloquée pour toujours**.

### Faux positifs : épingler par empreinte, jamais désactiver la règle
Un identifiant **public** au format d'un secret (adresse de contrat `0x…`/`C…`/`G…`, transaction XDR, hash de mot de passe) déclenche la règle `generic-api-key`. Ces cas se neutralisent dans un **`.gitleaksignore` versionné**, par **empreinte** (`commit:file:rule:line`) et **commenté** — jamais en désactivant la règle : un **vrai** secret dans le même fichier doit rester attrapé.

---

## 19. Résumé en une phrase

> **Un seul dossier à backuper** (`~/Documents/Claude/<projet>/`), **deux sous-dossiers** : `repo/` pour ce qui va sur GitHub, `workspace/` pour tout le reste. **Une seule source de vérité** par type de secret. **Zéro SSH** — lecture via `gh` en PAT public-RO, écriture via PAT fine-grained **1-repo** exposé par direnv (remote en URL nue). **Branche + PR pour les changes infra**, pin versionné en prod. **À plusieurs : un working tree isolé par intervenant** (worktree ou clone), branch protection sur `main`.
