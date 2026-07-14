# MÉTHODE — une seule source de vérité

> **Règle posée par Romain le 2026-07-14, après avoir dû réordonner trois passes de cohérence.**
> **Elle ne se rediscute pas. Elle s'applique à CHAQUE écriture, dans CE projet et dans tous ceux qu'il génère.**

---

## La règle

**Un fait vit à UN SEUL endroit. Partout ailleurs : un lien — jamais une copie.**

Le mal n'est pas la longueur d'un document : c'est **la concurrence entre plusieurs sources**.
Quand le même fait est écrit dans le script, le runbook, le standard *et* le suivi, **les quatre copies divergent** — c'est mécanique. Et le jour où l'une d'elles ment, on tourne en rond en cherchant laquelle croire.

> **Ce n'est pas une hypothèse.** `configure-repo.sh` a porté un commentaire affirmant *« CodeQL : via le workflow committé, rien à activer ici »* — **soixante lignes au-dessus du code qui fait précisément l'activation**. Le script se contredisait lui-même, et c'est ce commentaire qu'on relisait pour décider.

---

## Où vit quoi

| Document | Contient | **Ne contient JAMAIS** |
|---|---|---|
| **`meta/ORGANISATION.md`** | **LE SUIVI.** Où on en est · ce qui reste · les décisions prises. **Assez pour qu'un humain OU une IA reprenne à froid.** | le détail des preuves · le récit des bugs · le pourquoi long |
| **`meta/archives/*.md`** | **LE DÉTAIL.** Le pourquoi, le comment, les preuves, les mesures, les sources. **Datés, par phase ou par sujet.** | — *(c'est le déversoir : il peut grossir)* |
| **`docs/RUNBOOK.md`** | **LES GESTES**, dans l'ORDRE, et **QUI les fait**. Les URL, les valeurs exactes, les pièges. | le pourquoi *(→ standard)* · l'historique *(→ archives)* |
| **`docs/claude-code-project-standard.md`** | **LES CONVENTIONS** et le **POURQUOI** des règles. | la procédure *(→ runbook)* · le récit des incidents *(→ archives)* |
| **le CODE** *(scripts, workflows)* | **ce que le code NE PEUT PAS dire** : une contrainte non évidente, un piège qui se rejouerait. | **le récit historique.** Jamais *« constaté le 14/07 sur test003… »* |

---

## Les commentaires dans le code — la règle qui fait le plus mal

**Le code dit ce qu'il FAIT. Le commentaire ne dit QUE ce que le code ne peut pas dire.**

✅ **Garder** — une contrainte qui se rejouerait si on l'ignorait :
```bash
# `gh api` écrit ses erreurs sur STDOUT : `$(gh api … || echo x)` produit '{"message":…}x'.
```

❌ **Supprimer** — le récit, la preuve, la date, l'incident :
```bash
# Ce piège a frappé QUATRE fois dans ce fichier, dont deux fois après avoir été documenté :
#   · le run_id du PATCH → le script annonçait « ✓ CodeQL ACTIVÉ » sur un repo PRIVÉ…
#   · topics → `[: {json} 0 : nombre entier attendu`…
#   (Constaté sur test005, 2026-07-14.)
```
→ **Ça va en archive.** Une ligne dans le code, le récit complet dans `meta/archives/`.

**Supprimer un commentaire n'est PAS perdre l'information** : elle vit dans l'archive, datée, avec sa preuve. **Elle est juste au bon endroit.**

---

## Les quatre documents principaux restent COURTS

**S'ils grossissent, le détail PART EN ARCHIVE — il ne se tasse pas.**

Un document qu'on ne relit plus ne sert plus à rien. Le runbook est lu **en faisant** : s'il est illisible, il n'est pas lu, et le geste est fait de mémoire — **et un geste récité de mémoire est un geste faux**.

**Trop de fichiers d'archive n'est PAS un problème** — tant que les liens sont là et respectés.
**Une arborescence légère** vaut mieux que 25 `.md` au même niveau qui mélangent les documents vivants et les archives.

---

## Le réflexe, à chaque écriture

Avant d'ajouter une information, **une seule question** :

> **« Ce fait existe-t-il déjà ailleurs ? »**

- **Oui** → **mettre un lien**, et corriger l'endroit d'origine s'il est faux.
- **Non** → **quel est son SEUL endroit ?** Le suivi, l'archive, le runbook, le standard, ou le code. **Un.**

**Et si un document grossit : on n'y tasse pas — on en sort le détail.**
