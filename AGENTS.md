# AGENTS.md — instructions pour tout agent de code

À lire avant de toucher à quoi que ce soit dans ce repo.
Ce fichier suit la convention [AGENTS.md](https://agents.md) ; Claude Code le lit via l'import `@AGENTS.md` de `CLAUDE.md` (local, non suivi).

> **Exemption de langue** : ce repo est en **français** *(standard §1)*. Les projets qu'il **génère**, eux, restent en **anglais** — les gabarits de `templates/repo/` le sont déjà.

## Ce que c'est

Ce repo **fabrique et configure** les projets. **Il n'est pas un projet.**
Son produit, c'est le **standard** *(la version manuelle du déploiement de projet)* ; les scripts n'en sont que **l'automatisation**.

## Structure — DEUX repos git, côte à côte, un seul ira sur GitHub

| | Remote | Contenu |
|---|---|---|
| **`repo/`** *(le cwd)* | → GitHub **privé** — `actarus314/project-template` | les outils, `templates/`, `docs/` |
| **`../workspace/`** | ❌ **aucun — jamais poussé** | le suivi, les archives, les recherches |

`workspace/` **ne doit JAMAIS gagner de remote** : il porte des noms de repos privés et des récits d'incidents. C'est ce qui permet à `repo/` de basculer public un jour sans rien nettoyer.

## Commandes

```bash
./init-project.sh <projet> <owner>/<repo> [parent] [--type static|node|generic] [--pages] [--artefact] [--staging]
./configure-repo.sh <owner>/<repo> [homepage] [description] [topics-csv] [--dry-run]
./check.sh   # rejoue les checks de la CI EN LOCAL, aux versions épinglées (local == github)
```

`configure-repo.sh` est **joué par Romain** avec un PAT admin **éphémère** — l'assistant n'a **jamais** `Administration`.

`check.sh` lit les versions épinglées dans `ci.yml` *(source unique)*, tire les binaires sous `.ci-tools/` *(gitignoré)* et rejoue shellcheck · actionlint · zizmor · gitleaks · renovate-config-validator. Ce qui passe en local passe la CI — mais **la CI reste l'autorité** *(elle seule vérifie le SHA256 des assets Linux et tourne en conditions réelles)*.

Le hook `pre-commit` le **relance tout seul, throttlé (24 h) et CONSULTATIF** : au 1er commit d'une fenêtre il rejoue `check.sh` et affiche le résultat sans **jamais** bloquer *(le seul blocage du hook reste gitleaks sur les fichiers stagés)*. Régler le délai : `CHECK_MAX_AGE_HOURS`. But : ne plus avoir à y penser, sans transformer un lint sans rapport en commit coincé.

## Discipline — PR-only

**`repo/` est PR-only.** On n'écrit **jamais** sur `main` directement : le hook `pre-push` le refuse *(il est le substitut du ruleset, absent tant que le repo est privé)*.

- Brancher `feat/…` → pousser → ouvrir la PR.
- Une **CI** *(`.github/workflows/ci.yml`)* valide chaque PR : elle lint ses **propres** workflows, génère des projets et linte **leurs** workflows en conditions réelles.
- **Merger seulement CI verte.** Vérifier, à chaque fois — jamais `gh pr checks` *(permission `Checks` non accordable)* :
  ```bash
  sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
  gh run list --commit "$sha" --json workflowName,status,conclusion
  ```
  Vert = **tout** workflow attendu est `completed/success`. Un workflow **absent** de la liste n'est **pas** un vert.

## Conventions

- **Français** dans ce repo *(exemption §1)* ; **anglais** dans tout ce qui est généré.
- **Doc** : une idée par phrase, une phrase par ligne. Un fait vit à **un seul endroit** — partout ailleurs, un lien *(voir `docs/METHODE.md`)*.

## Ne pas casser

- **`~/.claude/CLAUDE.md` pointe en chemin ABSOLU** vers `docs/claude-code-project-standard.md`, `docs/METHODE.md` et `docs/RUNBOOK.md`. Les déplacer casse **toutes** les sessions Claude Code, **en silence**.
- **`templates/repo/.envrc`, `templates/repo/CLAUDE.md` et `templates/repo/requirements-ci.txt` sont suivis via `git add -f`** : le `.gitignore` **modèle** voisin les ignorerait sinon *(`requirements-ci.txt` l'est EXPRÈS — soustrait au scan osv, cf. son commentaire dans ce `.gitignore`)*. **Ne jamais les `git rm --cached`.**
- **Ne jamais committer de secret.** `.env` et `.envrc` sont non suivis, et doivent le rester.
