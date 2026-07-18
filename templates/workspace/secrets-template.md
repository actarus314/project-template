# Secrets & Auth — <projet>
> **Fichier personnel, hors Git. Ne JAMAIS le commiter, le copier vers `repo/`, ou le partager.**

---

## 1. Lecture GitHub + auth Git par défaut (`gh` CLI, public-RO)

`gh` CLI configuré une fois par machine avec un PAT **fine-grained « Public repositories (read-only) »** : lecture de tout le GitHub public à 5000 req/h, **aucun accès aux repos privés**. Token volontairement inoffensif (une fuite ne donne rien de plus que ce qui est déjà public).

L'écriture (push/PR) ne passe PAS par ce token — elle vient du PAT du repo, exposé par direnv (voir §2).

**Setup (une fois par machine) :**
```bash
brew install gh direnv
# Créer un fine-grained PAT "Public repositories (read-only)" sur
# https://github.com/settings/personal-access-tokens
#   Resource owner = <ton compte> · Repository access = Public repositories (read-only)
#   Account permissions = aucune · expiration = AUCUNE (assumé : RO sur du public, une fuite
#   ne donne accès qu'à ce qui est déjà public — cf. standard §5. Les PAT d'ÉCRITURE, eux, sont à 90 j.)
echo "<PAT-public-RO>" | gh auth login --with-token
gh auth setup-git        # git délègue son auth à gh (helper « gh auth git-credential »)
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc   # hook direnv
```

**Vérification :**
```bash
gh auth status
gh api rate_limit --jq .rate     # "limit" doit valoir 5000
gh api repos/<owner>/<un-repo-prive>   # doit renvoyer 404 (privé inaccessible = OK)
```

---

## 2. PAT d'écriture du repo (push, PR, issues) — 1 par repo, via direnv

**Token** : fine-grained, **restreint à CE SEUL repo** (owner = compte ou org du repo).
**Valeur** : dans `repo/.envrc` comme `GITHUB_PAT` — nulle part ailleurs, **jamais dans l'URL du remote**.
**Régénération** : https://github.com/settings/personal-access-tokens
**Repository access** : Only select repositories → ce repo uniquement.
**Permissions (standard homogène — matrice complète : `docs/github-repo-config.md §2`)** :
  - Contents : Read & Write
  - Metadata : Read (obligatoire / auto)
  - Pull requests : Read & Write
  - Issues : Read & Write
  - Workflows : Read & Write (indispensable dès qu'il y a un `.github/workflows/`, sinon push rejeté)
  - Actions : Read & Write (état CI + relancer/annuler un run)
  - Dependabot alerts : Read & Write (voir + dismiss/reopen en autonomie)
  - Code scanning alerts : Read & Write (voir + dismiss en autonomie)
  - Secret scanning alerts : Read (dismiss réservé à Romain — rejeter à tort une vraie fuite = trop d'impact)
  - **Tout le reste : No access** (surtout PAS d'Administration)

**Durée** : **90 jours** (standard §5 — tout nouveau PAT).
**Dernière génération** : YYYY-MM-DD
**Expire le** : YYYY-MM-DD

> **Alerte automatique** : `.envrc` prévient dans le terminal **14 jours avant** l'expiration (il lit le header `GitHub-Authentication-Token-Expiration`, 1 appel/jour max).
> L'expiration n'est donc jamais subie en pleine session — mais **penser à reporter la nouvelle date ici** après chaque rotation.

**Exposition à git/gh via direnv.** Le remote reste en **URL nue** (`https://github.com/<owner>/<repo>.git`). Le PAT n'est rendu visible à git/gh **que dans ce dossier**, par direnv :
- `repo/.envrc` (gitignoré) contient le PAT et reste **sourçable en bash** (pas de builtin `dotenv`, pour l'outil Bash non-interactif) :
  ```
  set -a; [ -f .env ] && . ./.env; set +a   # charge les vars app de .env (équivalent bash de `dotenv`)
  export GITHUB_PAT=<PAT 1-repo>
  export GH_TOKEN="$GITHUB_PAT"
  ```
- `direnv allow` une fois. En entrant dans le dossier → `GH_TOKEN` chargé → `git push`/`gh` utilisent le PAT du repo. En sortant → retour au public-RO.
- **Outil Bash de Claude (non-interactif)** : direnv ne charge pas seul → **préfixer par `direnv exec . git …`** (depuis `repo/` ; `direnv exec` ne change pas le CWD, requiert `direnv allow`).

**Usage :** plus besoin de `source .env` — direnv charge tout automatiquement dans le dossier.
```bash
git push                                   # auth via le PAT du repo (direnv)
gh pr create --title "..." --base main
gh issue list
gh run list
```

---

## 3. API Keys de l'application

Toutes stockées dans `repo/.env`. **Une seule source de vérité, pas de duplication ailleurs.**

| Variable | Service | Où régénérer |
|---|---|---|
| `...` | ... | ... |

---

## 4. Checklist en cas de compromission

Si une clé est exposée (commit accidentel, fuite, chat public, etc.) :
1. **Révoquer immédiatement** sur le dashboard du service concerné.
2. **Régénérer** une nouvelle clé.
3. **Mettre à jour** `repo/.env`.
4. **Redémarrer** l'app (ou `docker compose up -d` si container).
5. **Vérifier** les logs pour activité suspecte dans les dernières heures.

---

## 5. Rappel : où est ce qui est

| Donnée | Emplacement |
|---|---|
| PAT lecture publique (`gh` par défaut) | trousseau macOS (via `gh auth login --with-token`) |
| PAT d'écriture du repo (1-repo) | `repo/.envrc` (`GITHUB_PAT`, gitignoré) |
| Pont PAT → git/gh | `repo/.envrc` (`export GH_TOKEN=$GITHUB_PAT`) |
| Clés API applicatives | `repo/.env` |
| Permissions Claude Code | `repo/.claude/settings.local.json` (hors Git) |
| Instructions projet pour Claude | `repo/CLAUDE.md` (hors Git) |
