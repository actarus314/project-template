---
name: new-project
description: Use when Romain wants to create, initialise, scaffold or set up a NEW project/repo, or configure an existing one, or flip a repo from private to public, or add a capability (Docker image, staging host, GitHub Pages) to a live repo. Triggers on "initialise un projet", "crée un projet", "nouveau repo", "passe le repo en public", "configure ce repo". Drives the full runbook step by step, stopping at every action Romain must perform himself.
---

# Créer / configurer un projet — dérouler le RUNBOOK

## Les deux documents, et lequel fait foi sur quoi

Ils ne se remplacent pas — ils répondent à deux questions différentes. **Les confondre, c'est soit improviser la procédure, soit violer les conventions.**

| Document | Répond à | Quand le lire |
|---|---|---|
| 🎯 **`docs/RUNBOOK.md`** | **QUOI faire, dans quel ORDRE, et QUI le fait.** URL, permissions exactes, commandes complètes, pièges. | **INTÉGRALEMENT, avant de commencer.** C'est le fil à dérouler. |
| 📖 **`docs/claude-code-project-standard.md`** | **POURQUOI**, et les **conventions à tenir pendant qu'on développe** : arborescence, secrets, branches, README, docs de vie. | **Déjà imposé à chaque session** par `~/.claude/CLAUDE.md`. **Si ce n'est pas fait dans cette session : le lire MAINTENANT** — le runbook y renvoie sans cesse (« standard §12 »…), et **un renvoi non lu est un renvoi mort**. |

**Chemins :**
- `/Users/romain/Documents/Claude/template/repo/docs/RUNBOOK.md`
- `/Users/romain/Documents/Claude/template/repo/docs/claude-code-project-standard.md`

> 🔴 **Ne JAMAIS dérouler ces étapes de mémoire.** Elles portent des URL, des permissions exactes et des pièges précis, et elles changent. **Une étape récitée de mémoire est une étape fausse.**

**Les sections du standard réellement engagées ici** *(à ouvrir quand le runbook y renvoie, pas à réciter)* :
**§5** auth GitHub et matrice des PAT · **§10** initier un projet · **§12** politique de branches (les 3 capacités) · **§17** config du repo · **§18** la matrice des contrôles + les procédures *(flip privé→public, acquérir une capacité)*.

> ⚠️ **En cas de CONTRADICTION entre les deux : le RUNBOOK fait foi sur la PROCÉDURE** (l'ordre, les valeurs, les URL — il est tenu à jour pour l'exécution). **Le STANDARD fait foi sur les CONVENTIONS** (le pourquoi, les règles de fond).
> **Et il faut SIGNALER la contradiction à Romain** au lieu de choisir en silence : deux docs qui divergent, c'est un défaut du template — pas un arbitrage à faire en passant.

## Les 4 règles, non négociables

### 1. S'ARRÊTER à chaque geste de Romain

Le runbook marque **qui fait quoi**. Certains gestes sont **impossibles** pour l'assistant (il n'a **jamais** `Administration`) :
créer le repo · créer/révoquer un PAT · `direnv allow` · jouer `configure-repo.sh` · flipper la visibilité · rendre un package ghcr public · installer Renovate.

Pour chacun :
- **Donner l'URL directe** et **les valeurs exactes** (nom du token, expiration, permissions une par une).
- **S'ARRÊTER. Attendre sa confirmation.** Ne **jamais** enchaîner en supposant que c'est fait.
- Puis **VÉRIFIER** en lecture que c'est bien fait, avant de continuer.

### 2. Poser les 3 questions AVANT de taper la commande

Elles décident de toute l'architecture (`AskUserQuestion`) :

| | Question | Flag |
|---|---|---|
| **a** | Le site sera-t-il servi par **GitHub Pages** ? | `--pages` |
| **b** | Le repo **publiera-t-il une image que quelqu'un d'AUTRE déploie** ? *(auto-hébergeurs, un NUC…)* | `--artefact` |
| **c** | Existe-t-il un **host à VALIDER** avant la prod ? | `--staging` |

Plus la **toolchain** : `--type static` (aucun npm) ou `--type node` (npm, tests, types).

> 🔴 **`develop` découle de (c), JAMAIS de Docker ni du langage.** Un projet `node` sans host à valider n'en a pas. Un site Pages packagé en image non plus.

**Ne pas deviner ces réponses.** Si Romain dit juste « initialise un projet », **les poser**.

### 3. Ne rien inventer, tout vérifier

- **Les permissions du PAT** : les lire dans le runbook, **les énoncer une par une**. Une permission manquante **échoue en SILENCE** — tout le reste passe, et le contrôle absent ne se voit pas.
- **Après chaque étape**, vérifier le résultat réel (`gh api`, `git ls-files`, la CI) — **jamais supposer**.
- Si quelque chose ne correspond pas au runbook : **le dire**, ne pas improviser.

### 4. Ne JAMAIS oublier la révocation du PAT admin

> 🔴🔴 **C'est l'étape qu'on oublie, et la plus dangereuse à oublier.**
> Le PAT admin peut **supprimer le repo** et **changer sa visibilité**. Dès que `configure-repo.sh` a fini :
> **→ https://github.com/settings/personal-access-tokens — RÉVOQUER MAINTENANT.**
> Le rappeler **explicitement**, et **attendre confirmation**. *Un rappel n'est pas une révocation.*

## Les autres parcours du runbook

La même skill couvre :

- **§2 — travailler au quotidien** : `feat/` → PR → CI verte → merge. ⚠️ En privé, **rien n'exige la CI** : `gh pr checks <n>` **doit sortir 0** avant tout merge. C'est le **seul point resté humain**.
- **§3 — publier une version** : CHANGELOG → tag `v*` → Release + image. ⚠️ **1ʳᵉ release : rendre le package ghcr PUBLIC**, sinon personne ne peut auto-héberger.
- **§4 — basculer privé → public** : **le moment le plus dangereux du cycle de vie** (tout l'historique devient public d'un coup). Suivre les 8 étapes **dans l'ordre**, en commençant par `gitleaks` sur **toutes les refs**.
- **§5 — acquérir une capacité** sur un repo vivant. ⚠️ **L'ORDRE est un piège** : le workflow doit atteindre `main` **AVANT** que `configure-repo.sh` n'exige `build-check` — sinon **le repo se verrouille lui-même**.
- **§6 — maintenance** : Dependabot et Renovate en autonomie. 🔴 **Les alertes SECRET SCANNING sont réservées à Romain.**

## Les docs de vie — CHERCHER AVANT DE FABRIQUER

Le template pose par défaut `SUIVI.md` / `BACKLOG.md` dans `workspace/docs/`.
**Ce sont un DÉFAUT, pas un dogme** — `init-project.sh --no-lifecycle-docs` les omet.

> 🔴 **Tout projet est initialisé par ce template, y compris ceux qui seront conduits par un système tiers.**
> Imposer nos fichiers de suivi les mettrait en **COLLISION** avec le sien (`.planning/` de GSD & co.).
> **Deux systèmes de suivi concurrents = zéro système tenu.**

**À faire, au moment de créer le projet :**

1. **DEMANDER** à Romain si le projet sera piloté par un système de gestion *(GSD, superpowers, autre)*.
   - **Oui** → `--no-lifecycle-docs`. **Ce système porte le principe**, nos fichiers seraient un doublon.
   - **Non / il ne sait pas** → poser le défaut *(`SUIVI.md` + `BACKLOG.md`)*.

2. 🔴 **Si AUCUN outil n'est explicitement appelé — CHERCHER CE QUI EXISTE AVANT D'EN FABRIQUER UN.**
   **~100 skills sont installées**, dont **tout GSD** : `gsd-progress` · `gsd-resume-work` · `gsd-pause-work` · `gsd-review-backlog` · `gsd-capture` · `gsd-docs-update`…
   **Utiliser `find-skills`** — elle sert exactement à ça. Regarder aussi les **agents**, les **plugins**, le **marketplace**, les **fonctionnalités natives**.
   **Ne construire du custom qu'à défaut, et le DIRE.**

> **Le principe, lui, vaut quel que soit l'outil qui le porte** *(standard §16)* :
> un doc de reprise **CONCIS** qui **RENVOIE** au détail · un backlog **BREF** qui **POINTE** vers un plan · **le livré est PURGÉ**.
> *Un doc de suivi qu'on ne relit plus ne suit plus rien.*

## Discipline sur les secrets

- **Ne JAMAIS afficher la valeur d'un PAT.** Tester un **booléen**, jamais imprimer :
  `[ -n "$GITHUB_PAT" ] && echo "PAT chargé ✓"`
- **Ne jamais réécrire un fichier portant un secret par position de ligne.**
- Le PAT vit **uniquement** dans `repo/.envrc` — jamais dans `.env`, jamais dans l'URL du remote.

## Le piège du `direnv allow`

`init-project.sh` fait un `direnv allow` — **mais sur un `.envrc` VIDE**. Quand Romain y colle le PAT, il **modifie le fichier** → direnv **révoque** son autorisation.
**Sans un SECOND `direnv allow`, le `.envrc` n'est jamais chargé** → `git push` échoue en **403**, alors que le token est bien dans le fichier.
**Le lui rappeler explicitement**, et vérifier ensuite que le PAT est chargé.
