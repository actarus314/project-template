# Project Template — Claude Code

Scaffolds a GitHub project that is **hardened from its first commit**, and sets the server-side configuration no generator usually reaches — rulesets, secret scanning, dependency alerts, CodeQL, immutable releases.

It is **not** a project itself, and not a scaffolder in the usual sense: its product is a **standard** — the manual version of project deployment — and the scripts are only its automation. Anything they cannot do is handed back explicitly, with the exact URL and values.

## Why this exists

Setting up a project properly is not one action, it is several dozen: branch protection, required checks, secret scanning, dependency alerts, a bot that bumps pinned tools, an immutable tag, a license boundary, and the privileged token that does all this and must then be revoked.

**Redone from memory on each new project, they get redone wrong** — and wrong here is *silent*. A missing setting raises no error: an alert that never fires, a check that is never required, a scan that never runs. The gap surfaces the day it costs something.

Three findings shape this repo, and each one was paid for:

- **The order matters, and it is counter-intuitive.** A required check declared *before* the workflow that produces it locks the repository against every pull request — including the one that would fix it. This repo did it to itself, on going public.
- **Not everything is scriptable, and pretending otherwise is worse than admitting it.** Creating a token, flipping visibility, installing a bot: GitHub keeps those in the UI. So the runbook names which actions belong to a human, gives the direct URL and the exact values, and stops there.
- **A rule without its *why* gets dropped.** So the standard carries the why, the runbook carries the order and who acts, the scripts carry their own technical constraints — and a given fact lives in exactly **one** of them, never copied into the others.

The other structuring rule: **what SERVES to create a project** and **what TELLS how this template was built** are two different things, and they no longer mix — hence the two repos below.

## Create a project

```bash
./init-project.sh <project> <owner>/<repo> [parent-folder] \
    [--type static|node|generic] [--pages] [--artefact] [--staging]
```

`--type` decides **only the toolchain** (which `ci.yml`). Everything else follows **three independent capabilities**:

| Capability | The question to ask | What it brings |
|---|---|---|
| `--pages` | Is the site served by **GitHub Pages**? | `pages.yml` |
| `--artefact` | Does the repo **publish an image that someone ELSE deploys**? | ghcr image · Trivy · tags ruleset · immutable releases |
| `--staging` | Is there a **host to VALIDATE** before prod? | `develop` branch · 3-stage flow |

> **`develop` follows from `staging`** — never from Docker, never from the language. A `node` project with no host to validate does not have one; a Pages site packaged as an image doesn't either.

**Shortcuts**: `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging` · `--type generic` ≡ **no capability** *(any other toolchain — Android, C/C++, Rust… : security checks only, build/test to fill in)*.

## Configure the repo server-side

```bash
./configure-repo.sh <owner>/<repo> [homepage] [description] [topics-csv] [--dry-run]
```

Rulesets, secret scanning, Dependabot alerts, immutable releases, Pages, description, **topics**, and **CodeQL activation** *(native default setup — it detects languages and keeps them up to date on its own; there is **no longer** a `codeql.yml`)*. **Run by the maintainer** with an **ephemeral** admin PAT — the assistant never has `Administration: write`.

⚠️ **Replayed on the switch to public**: a private repo on the Free plan has **neither ruleset, nor secret scanning, nor CodeQL**. The script is **idempotent**, that's what it's for — and it's this replay that **activates CodeQL** on the flip.
`--dry-run` reads everything and **writes nothing** — to be used on a live repo.

## Verify locally — `local == github`

```bash
./check.sh
```

Replays **the CI's security checks** at **pinned versions** (auto-detected from `ci.yml`, so nothing to maintain by hand): what passes here passes the CI. It is **copied into every generated project**, and a `pre-commit` hook replays it on its own — throttled (24h) and **advisory** (it has never blocked a commit).

## Which version am I running?

```bash
./init-project.sh --version
```

The **git tag** is the single source, because a ruleset makes it immutable — the scripts read it, they never store it *(the why: `docs/repo-controls.md`)*. `verify-version.sh`, run by `check.sh` and by the CI, fails the build if the tag, the changelog and the scripts ever disagree.

A generated project records the version that built it, in its own `AGENTS.md`: it carries a **frozen copy** of the templates, so knowing which one is what makes a later fix diffable.

---

## What's in this folder

The template applies to itself the tree structure it imposes *(standard §2)*: **two distinct git repos**, side by side.

```
template/
├── repo/         ← THIS folder. Versioned → GitHub. The tools and the reference.
└── workspace/    ← The project's memory. LOCAL git repo, no remote — never pushed.
```

| | Role |
|---|---|
| **`init-project.sh`** · **`configure-repo.sh`** · **`check.sh`** · **`open-pr.sh`** · **`verify-version.sh`** | **The tools.** What gets run. |
| **`templates/`** | **What gets COPIED into a project** — and nothing else. `repo/` (versioned files) · `workflows/` (CI) · `workspace/` (outside Git). |
| **`skills/`** | **`new-project/`** — the Claude Code skill that runs through the RUNBOOK, stopping at every action the maintainer must perform themselves. Canonical here, never under `templates/`: nothing duplicates into generated projects. |
| **`docs/`** | **The reference, to be read as needed.** The method, the standard, the runbook, the map of checks. |
| **`../workspace/`** | **How this template was built.** Log, decisions, research, defects found. To be read to understand *why*, never to *do*. |

### `docs/` — the reference

- 🎯 **`RUNBOOK.md`** — **the full lifecycle, end to end**: create · work · release a version · switch private→public · evolve · maintain. **It states the ORDER OF ACTIONS and WHO does them**; the standard states the *why*. **This is the operational document — start with it.**
- **`METHODE.md`** — **a single source of truth**: a fact lives in one place, everywhere else a link. **Read at every session** *(imposed by `~/.claude/CLAUDE.md`)*.
- **`claude-code-project-standard.md`** — the standard. **Read at every session** *(same)*. It is also the **index**: a section that moved into its own file is kept there as a one-line pointer, so its number still resolves.
- **`secrets-and-auth.md`** — the two secret locations, the PAT model *(public-RO read · 1-repo write · ephemeral admin)*, and where each permission is derived from.
- **`claude-code-setup.md`** — configuring the assistant on a project: `CLAUDE.md`, `.claude/`, the persistent memory, delegation.
- **`docker-hardening.md`** — deployment security for a self-hosted service.
- **`repo-controls.md`** / **`.html`** — **how code reaches production, and what verifies it**: the branch policy and the three capabilities, the version pin, the repo configuration, the control matrix. The `.md` version is **authoritative**; the `.html` is its layout.
- **`security-and-updates.md`** / **`.html`** — **what moves, who decides it moves**: the three bump channels, Renovate as the sole auto-detecting bot, the checks on every PR.

### At the root

**`AGENTS.md`** — read this before touching anything: structure, commands, the PR-only rule, what must not be broken. · **`CONTRIBUTING.md`** — how to open a PR here. · **`SECURITY.md`** — report a flaw **privately**, never as a public issue. · **`CHANGELOG.md`** — what changed, for whoever uses the repo.

### `../workspace/` — the build

- **`SUIVI.md`** — the log *(the hot one)*. **To open first** to resume work. Short, it **points** to the archives.
- **`archives/`** — *the cold one*: one folder per closed stage *(`conception/`, `tests-grandeur-nature/`, `template-sous-git/`)*, each **synthesized** *(what/how/why)*. The three pieces of research that settled things live in **`archives/conception/`**.

---

## Two things not to break

**The global pointer.** `~/.claude/CLAUDE.md` references `docs/` **via an absolute path**. Moving these files breaks every Claude Code session, silently.

**`workspace/` is not in this repo — and it must never enter it.** It carries the internal memory (private repo names, incidents). Its own git, **with no remote**, is what protects this repo the day it goes public.

---

## What this is not

Honest about the edges, so no one discovers them the hard way:

- **GitHub only.** Rulesets, Actions, ghcr, Dependabot, CodeQL — nothing here transposes to another forge.
- **Built for Claude Code.** The scripts run by hand just fine, but the skill and the instruction files target that tool.
- **Sized for solo or a small team** — `required_approving_review_count = 0`: self-approving would be theatre, so review is not enforced.
- **It does not update already-generated projects.** Each one carries a **frozen copy** of the templates; a later fix has to be carried over deliberately.
- **The build/test half is not universal.** The security checks are language-agnostic; the build and test steps still have to be filled in per language *(that's what `--type generic` leaves open)*.

## License — two of them, and the boundary matters

| What | License |
|---|---|
| **The tool** — scripts, docs, the skill | **PolyForm Noncommercial 1.0.0** *(`LICENSE`)* |
| **What the tool FABRICATES** — `check.sh`, `open-pr.sh`, everything under `templates/` | **MIT** *(`LICENSE-MIT`)* |

The exception is not a detail: `init-project.sh` copies those files **verbatim** into every project it generates. Under a single noncommercial license, **every generated project would inherit that restriction** — including projects whose author never asked for it and had no way of knowing. The tool is protected; what it produces is free.

🔴 **PolyForm Noncommercial is not an open source license** — the OSI definition forbids restricting the field of use — and GitHub therefore displays this repository as *"Other"*. That is deliberate, not an oversight.

---

# Project Template — Claude Code (français)

Génère un projet GitHub **durci dès le premier commit**, et pose la configuration côté serveur qu'aucun générateur n'atteint d'habitude — rulesets, secret scanning, alertes de dépendances, CodeQL, releases immuables.

Ce n'est **pas** un projet en soi, ni un scaffolder au sens habituel : son produit est un **standard** — la version manuelle du déploiement de projet — et les scripts n'en sont que l'automatisation.
Ce qu'ils ne peuvent pas faire est rendu explicitement, avec l'URL exacte et les valeurs.

## Pourquoi cet outil existe

Configurer un projet correctement n'est pas une action, ce sont plusieurs dizaines : protection de branche, checks requis, secret scanning, alertes de dépendances, un bot qui met à jour les outils épinglés, un tag immuable, une frontière de licence, et le token privilégié qui fait tout cela et doit ensuite être révoqué.

**Refaites de mémoire à chaque nouveau projet, elles sont refaites de travers** — et ici, le travers est *silencieux*.
Un réglage manquant ne lève aucune erreur : une alerte qui ne se déclenche jamais, un check qui n'est jamais requis, un scan qui ne tourne jamais.
L'écart n'émerge que le jour où il coûte quelque chose.

Trois constats façonnent ce dépôt, et chacun s'est payé au prix fort :

- **L'ordre compte, et il est contre-intuitif.** Un check requis déclaré *avant* le workflow qui le produit verrouille le repo contre toute pull request — y compris celle qui y remédierait. Ce repo se l'est infligé à lui-même, en passant en public.
- **Tout n'est pas scriptable, et prétendre le contraire est pire que de l'admettre.** Créer un token, basculer la visibilité, installer un bot : GitHub garde cela dans l'UI. Le runbook nomme donc les actions qui reviennent à un humain, donne l'URL directe et les valeurs exactes, et s'arrête là.
- **Une règle sans son *pourquoi* finit par être abandonnée.** Le standard porte donc le pourquoi, le runbook porte l'ordre et qui agit, les scripts portent leurs propres contraintes techniques — et un fait donné vit dans exactement **UN SEUL** d'entre eux, jamais copié dans les autres.

L'autre règle structurante : **ce qui SERT à créer un projet** et **ce qui RACONTE comment ce template a été construit** sont deux choses différentes, et elles ne se mélangent plus — d'où les deux repos ci-dessous.

## Créer un projet

```bash
./init-project.sh <project> <owner>/<repo> [parent-folder] \
    [--type static|node|generic] [--pages] [--artefact] [--staging]
```

`--type` décide **uniquement la toolchain** (quel `ci.yml`). Tout le reste suit **trois capacités indépendantes** :

| Capacité | La question à poser | Ce que ça apporte |
|---|---|---|
| `--pages` | Le site est-il servi par **GitHub Pages** ? | `pages.yml` |
| `--artefact` | Le repo publie-t-il **une image que quelqu'un d'AUTRE déploie** ? | image ghcr · Trivy · ruleset des tags · releases immuables |
| `--staging` | Existe-t-il un **host à VALIDER** avant la prod ? | branche `develop` · flux à 3 étapes |

> **`develop` découle de `staging`** — jamais de Docker, jamais du langage. Un projet `node` sans host à valider n'en a pas ; un site Pages packagé en image non plus.

**Raccourcis** : `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging` · `--type generic` ≡ **aucune capacité** *(toute autre toolchain — Android, C/C++, Rust… : uniquement les checks de sécurité, build/test à compléter)*.

## Configurer le repo côté serveur

```bash
./configure-repo.sh <owner>/<repo> [homepage] [description] [topics-csv] [--dry-run]
```

Rulesets, secret scanning, alertes Dependabot, releases immuables, Pages, description, **topics**, et **activation de CodeQL** *(default setup natif — il détecte les langages et les tient à jour tout seul ; il n'y a **plus** de `codeql.yml`)*.
**Exécuté par le mainteneur** avec un PAT admin **éphémère** — l'assistant n'a jamais `Administration: write`.

⚠️ **Rejoué au passage en public** : un repo privé sur le plan Free n'a **ni ruleset, ni secret scanning, ni CodeQL**.
Le script est **idempotent**, c'est fait pour ça — et c'est ce rejeu qui **active CodeQL** au moment de la bascule.
`--dry-run` lit tout et **n'écrit rien** — à utiliser sur un repo déjà actif.

## Vérifier en local — `local == github`

```bash
./check.sh
```

Rejoue **les checks de sécurité de la CI** à des **versions épinglées** (auto-détectées depuis `ci.yml`, donc rien à maintenir à la main) : ce qui passe ici passe la CI.
Il est **copié dans chaque projet généré**, et un hook `pre-commit` le rejoue de lui-même — limité à une fois par 24h et **consultatif** (il n'a jamais bloqué un commit).

## Quelle version est en cours d'utilisation ?

```bash
./init-project.sh --version
```

Le **tag git** est la source unique, parce qu'un ruleset le rend immuable — les scripts le lisent, ils ne le stockent jamais *(le pourquoi : `docs/repo-controls.md`)*.
`verify-version.sh`, exécuté par `check.sh` et par la CI, fait échouer le build si le tag, le changelog et les scripts ne sont pas d'accord.

Un projet généré enregistre la version qui l'a construit, dans son propre `AGENTS.md` : il porte une **copie figée** des templates, donc savoir laquelle est ce qui rend un correctif ultérieur diffable.

---

## Ce que contient ce dossier

Le template s'applique à lui-même la structure d'arborescence qu'il impose *(standard §2)* : **deux repos git distincts**, côte à côte.

```
template/
├── repo/         ← CE dossier. Versionné → GitHub. Les outils et la référence.
└── workspace/    ← La mémoire du projet. Dépôt git LOCAL, sans remote — jamais poussé.
```

| | Rôle |
|---|---|
| **`init-project.sh`** · **`configure-repo.sh`** · **`check.sh`** · **`open-pr.sh`** · **`verify-version.sh`** | **Les outils.** Ce qui s'exécute. |
| **`templates/`** | **Ce qui est COPIÉ dans un projet** — et rien d'autre. `repo/` (fichiers versionnés) · `workflows/` (CI) · `workspace/` (hors Git). |
| **`skills/`** | **`new-project/`** — la skill Claude Code qui déroule le RUNBOOK, en s'arrêtant à chaque action que le mainteneur doit accomplir lui-même. Canonique ici, jamais sous `templates/` : rien ne se duplique dans les projets générés. |
| **`docs/`** | **La référence, à lire au besoin.** La méthode, le standard, le runbook, la carte des checks. |
| **`../workspace/`** | **Comment ce template a été construit.** Journal, décisions, recherche, défauts trouvés. À lire pour comprendre le *pourquoi*, jamais pour *faire*. |

### `docs/` — la référence

- 🎯 **`RUNBOOK.md`** — **le cycle de vie complet, de bout en bout** : créer · travailler · publier une version · basculer privé→public · faire évoluer · maintenir. **Il énonce l'ORDRE DES ACTIONS et QUI les fait** ; le standard énonce le *pourquoi*. **C'est le document opérationnel — à commencer par lui.**
- **`METHODE.md`** — **une source unique de vérité** : un fait vit à un seul endroit, partout ailleurs un lien. **À lire à chaque session** *(imposé par `~/.claude/CLAUDE.md`)*.
- **`claude-code-project-standard.md`** — le standard. **À lire à chaque session** *(idem)*. Il en est aussi l'**index** : une section partie dans son propre fichier y reste en pointeur d'une ligne, si bien que son numéro résout toujours.
- **`secrets-and-auth.md`** — les deux lieux du secret, le modèle de PAT *(lecture public-RO · écriture 1 repo · admin éphémère)*, et d'où chaque permission est dérivée.
- **`claude-code-setup.md`** — configurer l'assistant sur un projet : `CLAUDE.md`, `.claude/`, la mémoire persistante, la délégation.
- **`docker-hardening.md`** — la sécurité de déploiement d'un service auto-hébergé.
- **`repo-controls.md`** / **`.html`** — **comment le code arrive en prod, et qui le vérifie** : la politique de branches et les trois capacités, l'épinglage de version, la configuration du repo, la matrice des contrôles. La version `.md` fait **autorité** ; le `.html` en est la mise en forme.
- **`security-and-updates.md`** / **`.html`** — **ce qui bouge, qui décide que ça bouge** : les trois canaux de bump, Renovate seul bot auto-détectant, les checks de chaque PR.

### À la racine

**AGENTS.md** — à lire avant de toucher à quoi que ce soit : structure, commandes, la règle PR-only, ce qu'il ne faut pas casser. · **CONTRIBUTING.md** — comment ouvrir une PR ici. · **SECURITY.md** — signaler une faille **en privé**, jamais comme issue publique. · **CHANGELOG.md** — ce qui a changé, pour quiconque utilise le repo.

### `../workspace/` — la fabrication

- **`SUIVI.md`** — le journal *(le chaud)*. **À ouvrir en premier** pour reprendre le travail. Court, il **pointe** vers les archives.
- **`archives/`** — *le froid* : un dossier par étape close *(`conception/`, `tests-grandeur-nature/`, `template-sous-git/`)*, chacune **synthétisée** *(quoi/comment/pourquoi)*. Les trois recherches qui ont tranché vivent dans **`archives/conception/`**.

---

## Deux choses à ne pas casser

**Le pointeur global.** `~/.claude/CLAUDE.md` référence `docs/` **via un chemin absolu**.
Déplacer ces fichiers casse chaque session Claude Code, silencieusement.

**`workspace/` n'est pas dans ce repo — et ne doit jamais y entrer.** Il porte la mémoire interne (noms de repos privés, incidents).
Son propre git, **sans remote**, est ce qui protège ce repo le jour où il passe en public.

---

## Ce que cet outil n'est pas

Honnête sur ses limites, pour que personne ne les découvre à ses dépens :

- **GitHub uniquement.** Rulesets, Actions, ghcr, Dependabot, CodeQL — rien ici ne se transpose vers une autre forge.
- **Construit pour Claude Code.** Les scripts tournent très bien à la main, mais la skill et les fichiers d'instructions ciblent cet outil.
- **Dimensionné pour du solo ou une petite équipe** — `required_approving_review_count = 0` : s'auto-approuver serait du théâtre, la review n'est donc pas imposée.
- **Il ne met pas à jour les projets déjà générés.** Chacun porte une **copie figée** des templates ; un correctif ultérieur doit être reporté délibérément.
- **La moitié build/test n'est pas universelle.** Les checks de sécurité sont agnostiques au langage ; les étapes de build et de test restent à remplir par langage *(c'est ce que laisse ouvert `--type generic`)*.

## Licence — il y en a deux, et la frontière compte

| Quoi | Licence |
|---|---|
| **L'outil** — scripts, docs, la skill | **PolyForm Noncommercial 1.0.0** *(`LICENSE`)* |
| **Ce que l'outil FABRIQUE** — `check.sh`, `open-pr.sh`, tout ce qui est sous `templates/` | **MIT** *(`LICENSE-MIT`)* |

L'exception n'est pas un détail : `init-project.sh` copie ces fichiers **tels quels** dans chaque projet qu'il génère.
Sous une licence noncommercial unique, **chaque projet généré hériterait de cette restriction** — y compris des projets dont l'auteur ne l'a jamais demandée et n'avait aucun moyen de le savoir.
L'outil est protégé ; ce qu'il produit est libre.

🔴 **PolyForm Noncommercial n'est pas une licence open source** — la définition de l'OSI interdit de restreindre le champ d'usage — et GitHub affiche donc ce repo comme *« Other »*.
C'est délibéré, pas un oubli.

