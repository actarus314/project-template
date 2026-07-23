# MÉTHODE — une seule source de vérité

> **Règle posée par Romain le 2026-07-14, après avoir dû réordonner trois passes de cohérence.**
> **Elle ne se rediscute pas. Elle s'applique à CHAQUE écriture, dans CE projet et dans tous ceux qu'il génère.**

---

## La règle

**Un fait vit à UN SEUL endroit. Partout ailleurs : un lien — jamais une copie.**

Le mal n'est pas la longueur d'un document : c'est **la concurrence entre plusieurs sources**.
Quand le même fait est écrit dans le script, le runbook, les conventions *et* le suivi, **les quatre copies divergent** — c'est mécanique. Et le jour où l'une d'elles ment, on tourne en rond en cherchant laquelle croire.

> **Ce n'est pas une hypothèse.** `configure-repo.sh` a porté un commentaire affirmant *« CodeQL : via le workflow committé, rien à activer ici »* — **soixante lignes au-dessus du code qui fait précisément l'activation**. Le script se contredisait lui-même, et c'est ce commentaire qu'on relisait pour décider.

---

## Où vit quoi — par RÔLE, pas par nom de fichier

Les rôles ci-dessous sont **stables** ; les fichiers qui les portent, non *(voir « L'outil de suivi est un défaut »)*.

| Rôle | Contient | **Ne contient JAMAIS** |
|---|---|---|
| **LE SUIVI** *(défaut : `workspace/docs/SUIVI.md`)* | Où on en est · les décisions · les pièges · **ce qui reste** *(bref — POINTE vers un plan si c'est lourd)*. **Assez pour qu'un humain OU une IA reprenne à froid.** | le détail des preuves · le récit des bugs · le pourquoi long · **le livré** *(purgé)* · les plans complets |
| **LES ARCHIVES** *(défaut : `workspace/docs/archives/<étape>/`)* | **LE DÉTAIL.** Le pourquoi, le comment, les preuves, les mesures, les sources. **Datés, par phase ou par sujet.** | — *(c'est le déversoir : il peut grossir)* |
| **LES GESTES** *(`RUNBOOK.md`)* | Les gestes, dans l'**ORDRE**, et **QUI les fait**. Les URL, les valeurs exactes, les pièges. | le pourquoi *(→ conventions)* · l'historique *(→ archives)* |
| **LES CONVENTIONS** *(`claude-code-project-standard.md`, les ADR)* | Les règles et le **POURQUOI** de chaque règle. | la procédure *(→ runbook)* · le récit des incidents *(→ archives)* |
| **LE CODE** *(scripts, workflows)* | **ce que le code NE PEUT PAS dire** : une contrainte non évidente, un piège qui se rejouerait. | **le récit historique.** Jamais *« constaté le 14/07 sur test003… »* |

---

## Les commentaires dans le code — la règle qui fait le plus mal

**Le code dit ce qu'il FAIT. Le commentaire ne dit QUE ce que le code ne peut pas dire.**

> **Le critère qui tranche, et il est mécanique : UN SCRIPT EST L'AUTOMATISATION D'UNE PRESCRIPTION ÉCRITE AILLEURS.**
> Le geste existe **d'abord** dans le runbook, la règle **d'abord** dans les conventions. Le script ne les invente pas — **il les exécute**. D'où :
>
> | Le commentaire explique… | Verdict |
> |---|---|
> | **une règle, un pourquoi, un défaut GitHub** *(« le package ghcr est privé d'office en org »)* | **copie du doc → SUPPRIMER**, laisser un renvoi. Le fait vit **dans le doc**. |
> | **une contrainte d'implémentation** *(« `gh api` écrit ses erreurs sur STDOUT »)* | **n'existe nulle part ailleurs, et n'a rien à faire dans le doc → GARDER.** |
>
> 🔴 **Et la contrainte marche dans l'AUTRE SENS — c'est là qu'est sa valeur.**
> **Tout ce que le script APPREND doit REMONTER au doc.** Un fait découvert en exécutant *(le comportement ghcr perso/org, découvert en testant)* n'a pas le droit de vivre **uniquement** dans le script : le doc cesserait d'être suffisant pour faire **à la main**, et il deviendrait faux par omission.
>
> ⚠️ **Ce que ça ne veut PAS dire** : « le doc doit tout dire ». Ce serait la porte de l'obésité — exactement ce qu'on combat. Le **standard** dit les conventions, le **runbook** dit les gestes, le **script** garde ses contraintes techniques.

✅ **Garder** — une contrainte qui se rejouerait si on l'ignorait :
```bash
# `gh api` écrit ses erreurs sur STDOUT : `$(gh api … || echo x)` produit '{"message":…}x'.
```

❌ **Supprimer** — le récit, la preuve, la date, l'incident :
```bash
# Ce piège a frappé QUATRE fois dans ce fichier, dont deux fois après avoir été documenté :
#   · le run_id du PATCH → le script annonçait « ✓ CodeQL ACTIVÉ » sur un repo PRIVÉ…
#   (Constaté sur test005, 2026-07-14.)
```
→ **Ça va en archive.** Une ligne dans le code, le récit complet dans les archives.

**Supprimer un commentaire n'est PAS perdre l'information** : elle vit dans l'archive, datée, avec sa preuve. **Elle est juste au bon endroit.**

---

## L'outil de suivi est un DÉFAUT, pas un dogme

`SUIVI.md` est ce que le générateur pose **par défaut** *(le suivi ET « ce qui reste » dans un seul doc vivant ; un chantier lourd bascule dans un plan)*. Ce sont les **rôles** qui comptent, pas les fichiers : le `.planning/` de GSD, un Linear, un Notion **satisfont la même règle** dès lors qu'un fait continue de vivre à **un seul endroit**.

- Ce que doit porter chaque document : **`claude-code-project-standard.md` §16**.
- Ne pas les vouloir du tout : `init-project.sh --no-lifecycle-docs`.
- 🔴 **Deux systèmes de suivi en parallèle = deux sources concurrentes** — précisément ce que cette règle interdit. **On en choisit UN.**

---

## Les documents principaux restent COURTS

**S'ils grossissent, le détail PART EN ARCHIVE — il ne se tasse pas.**

Un document qu'on ne relit plus ne sert plus à rien. Le runbook est lu **en faisant** : s'il est illisible, il n'est pas lu, et le geste est fait de mémoire — **et un geste récité de mémoire est un geste faux**.

**Trop de fichiers d'archive n'est PAS un problème** — tant que les liens sont là et respectés.
**Une arborescence légère** vaut mieux que 25 `.md` au même niveau qui mélangent les documents vivants et les archives.

---

## Clôturer une étape — le geste récurrent *(le SUIVI respire)*

**La doc est un chantier à part entière, à deux températures :**
- **CHAUD** — `SUIVI.md` : ce qui est *en cours* et *à venir*. Il **grossit** pendant une étape.
- **FROID** — `archives/<étape>/` : ce qui est *clos*. **Un dossier par étape terminée, ses recherches et ses preuves dedans.**

**À CHAQUE étape terminée** *(un chantier, une phase, un lot — pas chaque commit)* :

1. **Élaguer le chaud.** Sortir de `SUIVI.md` tout ce que l'étape a clos. Il **rétrécit** — c'est le signe que l'étape est finie.
2. **Écrire l'archive de l'étape — une SYNTHÈSE, JAMAIS un déplacement ni un dump** *(format ADR : contexte → décisions → conséquences)* :
   on **lit les sources en ENTIER**, puis on distille le **QUOI** *(ce qui a été fait)* **+ le COMMENT** *(les pièges rencontrés)* **+ le POURQUOI** *(pourquoi ces choix, ce qu'on a écarté)*.
   Objectif : **assez pour ne JAMAIS rouvrir un sujet clos faute d'info — et pas une ligne de plus.**
3. **Y ranger les recherches et les preuves** de l'étape *(un `RECHERCHE-*` est froid une fois fait — il va dans SON dossier d'étape, pas à la racine du chaud)*.
4. **Committer.** L'archive est immuable *(sauf renversement de paradigme du projet)*.

**L'arborescence reste LÉGÈRE** : quelques dossiers d'étape, quelques fichiers utiles chacun — **ni un congélateur géant, ni 38 dossiers de deux fichiers de 90 lignes.**

> 🔴 **Le piège — et il a été commis** *(15/07)* : **congeler le verbatim** du `SUIVI` dans un seul pavé de 114 Ko. Un congélateur qu'on **n'ouvre jamais** : si retrouver le *pourquoi* d'une ligne du chaud oblige à fouiller l'énorme archive, **on ne le fera pas**. L'archive se **synthétise** ; elle ne se **déverse** pas.

---

## Le réflexe, à chaque écriture

Avant d'ajouter une information, **une seule question** :

> **« Ce fait existe-t-il déjà ailleurs ? »**

- **Oui** → **mettre un lien**, et corriger l'endroit d'origine s'il est faux.
- **Non** → **quel est son SEUL endroit ?** Le suivi, l'archive, le runbook, les conventions, ou le code. **Un.**

**Et si un document grossit : on n'y tasse pas — on en sort le détail.**

---

## Déléguer : Claude est chef d'orchestre

**Dès qu'une tâche coûte MOINS cher déléguée** — ou qu'elle est **sensiblement plus rapide ou plus performante à coût égal** *(ou très légèrement supérieur)* — **Claude prend le rôle de chef d'orchestre et délègue** à un ou plusieurs sous-agents.

- Le sous-agent **fait le travail lui-même** : il ne re-délègue pas, et il **n'appelle pas l'advisor**.
- Il tourne souvent sur un modèle **plus rapide et moins coûteux** *(Sonnet, voire Haiku)* — l'orchestrateur garde le raisonnement, l'agent exécute.
- **Préférer les workflows** *(orchestration déterministe : fan-out en parallèle, pipeline, vérification adversariale)* **autant que possible et autant que pertinent** : un travail décomposable en tâches parallèles ou en étapes vérifiables gagne à être un workflow plutôt qu'une longue passe séquentielle.

Le but : l'orchestrateur dépense ses tokens à **décider**, pas à exécuter ce qu'un modèle plus léger fait aussi bien.
