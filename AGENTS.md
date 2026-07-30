# AGENTS.md — instructions pour tout agent de code

À lire avant de toucher à quoi que ce soit dans ce repo.
Ce fichier suit la convention [AGENTS.md](https://agents.md) ; Claude Code le lit via l'import `@AGENTS.md` de `CLAUDE.md` (local, non suivi).

> **Exemption de langue** : ce repo est en **français** *(standard §1)*. Les projets qu'il **génère**, eux, restent en **anglais** — les gabarits de `templates/repo/` le sont déjà.
> **Seule exception à l'exemption : `check.sh` ET `open-pr.sh` sont en anglais.** `init-project.sh` les copie **verbatim** dans chaque projet généré *(anglais)* — fichiers partagés, donc écrits dans la langue des générés, pas celle de ce repo. Ne pas les « re-franciser » au nom de §1.

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
./open-pr.sh <base> <titre> <fichier-corps>   # ouvre une PR ET s'assure que la CI démarre (via direnv exec)
```

`configure-repo.sh` est **joué par Romain** avec un PAT admin **éphémère** — l'assistant n'a **jamais** `Administration: write`.

`check.sh` lit les versions épinglées dans `ci.yml` *(source unique)*, tire les binaires sous `.ci-tools/` *(gitignoré)* et rejoue **tout ce que la CI lance** : shellcheck · actionlint · zizmor · **semgrep** · **osv-scanner** · gitleaks — plus la validation de tout `renovate.json` présent *(seul ajout délibéré : il attrape le gel silencieux des updates sur config cassée)*. Il est **auto-détectant** *(il lit le `ci.yml` du repo et ne lance QUE ce qui s'y trouve)*, donc le **même** fichier sert ce repo ET tout projet généré. Ce qui passe en local passe la CI — mais **la CI reste l'autorité** *(elle seule vérifie le SHA256 des assets Linux et tourne en conditions réelles)*.

Le hook `pre-commit` le **relance tout seul, throttlé (24 h) et CONSULTATIF** : au 1er commit d'une fenêtre il rejoue `check.sh` et affiche le résultat sans **jamais** bloquer *(le seul blocage du hook reste gitleaks sur les fichiers stagés)*. Régler le délai : `CHECK_MAX_AGE_HOURS`. But : ne plus avoir à y penser, sans transformer un lint sans rapport en commit coincé.

## Discipline — PR-only

**`repo/` est PR-only.** On n'écrit **jamais** sur `main` directement : le hook `pre-push` le refuse *(il est le substitut du ruleset, absent tant que le repo est privé)*.

- Brancher `feat/…` → **ouvrir la PR avec `direnv exec <repo> ./open-pr.sh <base> <titre> <fichier-corps>`** : il pousse, ouvre la PR, ET **vérifie qu'un run `pull_request` démarre** — GitHub omet parfois de dispatcher la CI, et une PR à **0 run** se lit comme un vert alors qu'elle n'a **jamais** été testée. S'il manque, il close/reopen pour re-tirer l'event *(seul re-déclencheur qui reproduit les checks REQUIS `pull_request`)*. 🔴 **« 0 run » n'est JAMAIS un vert.**
- Une **CI** *(`.github/workflows/ci.yml`)* valide chaque PR : elle lint ses **propres** workflows, génère des projets et linte **leurs** workflows en conditions réelles.
- **Merger seulement CI verte.** Vérifier, à chaque fois — jamais `gh pr checks` *(permission `Checks` non accordable)* :
  ```bash
  sha=$(gh pr view <n> --json headRefOid --jq .headRefOid)
  gh run list --commit "$sha" --json workflowName,status,conclusion
  ```
  Vert = **tout** workflow attendu est `completed/success`. Un workflow **absent** de la liste n'est **pas** un vert.
- **Après le merge, vérifier AUSSI le run `push` sur `main`** — autre event, donc autre run : le vert de la PR ne dit rien de celui-là, et c'est `main` qui fait foi.
  🔴 **`--commit` ne trouve PAS ce run — filtrer par BRANCHE.** Sur un SHA né d'un merge, `gh run list --commit <sha>` rend **0 run**, quand `--branch main` rend le run `CI [push]` portant **exactement ce `headSha`**, vert. Le filtre `--commit` marche sur les runs `pull_request` — d'où la commande ci-dessus, qui reste juste. Jouée telle quelle après un merge, elle rend « 0 run » : **le motif même que ce fichier apprend à lire comme un échec de dispatch.**
  ```bash
  gh run list --branch main --limit 5 --json headSha,workflowName,event,status,conclusion \
    --jq "[.[]|select(.headSha|startswith(\"$sha\"))]"
  ```

## Conventions

- **Français** dans ce repo *(exemption §1)* ; **anglais** dans tout ce qui est généré.
- **Doc** : une idée par phrase, une phrase par ligne. Un fait vit à **un seul endroit** — partout ailleurs, un lien *(voir `docs/METHODE.md`)*.
- **`CHANGELOG.md`** : une ligne dans `Non publié` dès qu'un changement se voit **de qui se sert du repo** *(un gabarit qui change, un geste du RUNBOOK qui bouge, un comportement de script)*. Pas de section versionnée — ce repo n'a ni tag ni release. Un refactor interne ou une correction de typo n'y va pas.

## Ne pas casser

- **`~/.claude/CLAUDE.md` pointe en chemin ABSOLU** vers `docs/claude-code-project-standard.md`, `docs/METHODE.md` et `docs/RUNBOOK.md`. Les déplacer casse **toutes** les sessions Claude Code, **en silence**.
- **`templates/repo/.envrc`, `templates/repo/CLAUDE.md` et `templates/repo/requirements-ci.txt` sont suivis via `git add -f`** : le `.gitignore` **modèle** voisin les ignorerait sinon *(`requirements-ci.txt` l'est EXPRÈS — soustrait au scan osv, cf. son commentaire dans ce `.gitignore`)*. **Ne jamais les `git rm --cached`.**
- **Ne jamais committer de secret.** `.env` et `.envrc` sont non suivis, et doivent le rester.
