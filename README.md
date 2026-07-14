# Template de projet — Claude Code

Ce dossier **fabrique et configure** les projets. Il n'est **pas** un projet.

La règle qui structure tout : **ce qui SERT à créer un projet** et **ce qui RACONTE comment ce template a été construit** sont deux choses différentes, et elles ne se mélangent plus.

---

## Créer un projet

```bash
./init-project.sh <projet> <owner>/<repo> [dossier-parent] \
    [--type static|node] [--pages] [--artefact] [--staging]
```

`--type` décide **uniquement la toolchain** (quel `ci.yml`). Tout le reste suit **trois capacités indépendantes** :

| Capacité | La question à se poser | Ce qu'elle apporte |
|---|---|---|
| `--pages` | Le site est-il servi par **GitHub Pages** ? | `pages.yml` |
| `--artefact` | Le repo **publie-t-il une image que quelqu'un d'AUTRE déploie** ? | image ghcr · Trivy · ruleset tags · immutable releases |
| `--staging` | Existe-t-il un **host à VALIDER** avant la prod ? | branche `develop` · flux 3 étages |

> **`develop` découle du `staging`** — jamais de Docker, jamais du langage. Un projet `node` sans host à valider n'en a pas ; un site Pages packagé en image non plus.

**Raccourcis** : `--type static` ≡ `--pages` · `--type node` ≡ `--artefact --staging`.

## Configurer le repo côté serveur

```bash
./configure-repo.sh <owner>/<repo> [homepage] [description] [topics-csv] [--dry-run]
```

Rulesets, secret scanning, Dependabot, immutable releases, Pages, description, **topics**, et **l'activation de CodeQL** *(default setup natif — il détecte les langages et les tient à jour tout seul ; il n'y a **plus** de `codeql.yml`)*. **Joué par Romain** avec un PAT admin **éphémère** — l'assistant n'a jamais `Administration`.

⚠️ **Se rejoue au passage en public** : un repo privé en plan Free n'a **ni ruleset, ni secret scanning, ni CodeQL**. Le script est **idempotent**, c'est fait pour — et c'est ce rejeu qui **active CodeQL** au flip.
`--dry-run` lit tout et **n'écrit rien** — à utiliser sur un repo vivant.

---

## Ce qu'il y a dans ce dossier

Le template s'applique à lui-même l'arborescence qu'il impose *(standard §2)* : **deux repos git distincts**, côte à côte.

```
template/
├── repo/         ← CE dossier. Versionné → GitHub. Les outils et la référence.
└── workspace/    ← La mémoire du projet. Repo git LOCAL, sans remote — jamais poussé.
```

| | Rôle |
|---|---|
| **`init-project.sh`** · **`configure-repo.sh`** | **Les outils.** Ce qu'on exécute. |
| **`templates/`** | **Ce qui est COPIÉ dans un projet** — et rien d'autre. `repo/` (fichiers versionnés) · `workflows/` (CI) · `workspace/` (hors Git). |
| **`docs/`** | **La référence, à lire à l'usage.** La méthode, le standard, le runbook, la carte des contrôles. |
| **`../workspace/`** | **Comment ce template a été construit.** Journal de bord, décisions, recherches, les défauts trouvés. À lire pour comprendre *pourquoi*, jamais pour *faire*. |

### `docs/` — la référence

- 🎯 **`RUNBOOK.md`** — **le cycle de vie complet, de bout en bout** : créer · travailler · publier une version · basculer privé→public · faire évoluer · maintenir. **Il dit l'ORDRE DES GESTES et QUI les fait** ; le standard dit le *pourquoi*. **C'est le document opérationnel — commencer par lui.**
- **`METHODE.md`** — **une seule source de vérité** : un fait vit à un seul endroit, partout ailleurs un lien. **Lue à chaque session** *(imposée par `~/.claude/CLAUDE.md`)*.
- **`claude-code-project-standard.md`** — le standard. **Lu à chaque session** *(idem)*.
- **`github-repo-config.md`** — contrôles serveur, matrice des PAT, checklist nouveau repo.
- **`controles-repo.md`** / **`.html`** — quel contrôle tourne, où, avec quel outil. La version `.md` **fait foi** ; le `.html` en est la mise en page.

### `../workspace/` — la construction

- **`SUIVI.md`** — le journal de bord. **À ouvrir en premier** pour reprendre le chantier.
- **`RECHERCHE-*.md`** — les trois recherches qui ont tranché : auth GitHub, config serveur, outils existants.

---

## Deux choses à ne pas casser

**Le pointeur global.** `~/.claude/CLAUDE.md` référence `docs/` **en chemin absolu**. Déplacer ces fichiers casse toutes les sessions Claude Code, silencieusement.

**`workspace/` n'est pas dans ce repo — et il ne doit jamais y entrer.** Il porte la mémoire interne (noms de repos privés, incidents). Son propre git, **sans remote**, est ce qui protège ce repo-ci le jour où il passera public.
