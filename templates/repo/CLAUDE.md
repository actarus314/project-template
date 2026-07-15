# <projet> — instructions Claude Code

> Fichier local, **ignoré par Git**. Lu automatiquement par Claude Code à chaque session.

## Les règles du projet sont dans AGENTS.md

@AGENTS.md

> `AGENTS.md` est **versionné** et lu par tous les agents (convention [agents.md](https://agents.md)).
> Il porte : commandes, structure, politique de branches, conventions de code, contrôles, ne-pas-toucher.
> **Ne pas dupliquer ici ce qui est déjà là-bas** — deux copies divergent toujours.
> Ce fichier-ci ne garde que ce qui est **personnel** et n'a rien à faire sur GitHub.

## Standard d'organisation (perso)
`/Users/romain/Documents/Claude/template/repo/docs/claude-code-project-standard.md`
(déjà imposé par `~/.claude/CLAUDE.md` — le relire en cas de doute).

## Pointeurs workspace (repo git LOCAL — sans remote, jamais poussé)
- Secrets / auth : `../workspace/secrets.md`
- Docs / archi : `../workspace/docs/` — **`SUIVI.md` à lire en premier après un `/clear`** *(le seul doc vivant : état + « ce qui reste »)*
- Plans / roadmap : `../workspace/plans/`
- Notes : `../workspace/notes/`

## Auth GitHub — le piège du shell non-interactif
- L'outil Bash de Claude Code lance un shell **non-interactif** : **direnv ne charge rien**.
  → `set -a; source ./.envrc; set +a` **avant tout `git push` / `gh`**, depuis `repo/`.
- Le PAT vit dans **`.envrc`** (`GITHUB_PAT`), jamais dans `.env` (fuite conteneur via `env_file`).
- Remote en **URL nue** — un PAT dans l'URL du remote est une fuite en clair dans `.git/config`.
- `gh` lancé **hors** du dossier retombe sur le PAT public-RO : une org peut le refuser.

## Docs de vie — à tenir de moi-même
- `../workspace/docs/SUIVI.md` : consolider (état, décisions, ce qui reste) · purger le livré.
- `CHANGELOG.md` (versionné) : section `Unreleased` à chaque change visible par l'utilisateur.

> Aucun secret dans ce fichier (discipline zéro-secret sur tout fichier nommé).
