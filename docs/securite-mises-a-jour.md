# Processus sécu & mises à jour du template

> Référence. Comment une mise à jour entre dans le repo — et ce qui la contrôle.
> Le principe : **toujours à jour, mais par gestes revus** — jamais de dérive silencieuse, jamais d'adoption au jour zéro.

Trois canaux distincts font monter les versions ; six outils vérifient le code à chaque PR.
**Un seul bot d'update — Renovate — auto-détecte tout** ce qui doit monter, sans liste à tenir.

**Légende des acteurs :** système / pin · automatique · geste humain · trou / manuel.

---

## Le flux — trois canaux de montée en version

Chaque canal a son déclencheur, son délai, sa porte (la CI) et son décideur au merge.
Ils divergent au moment clé : **version → un humain merge**, **sécurité → auto-merge**.

### Canal 1 — dépendance du code

*Déclenché par toi · décidé par toi · impact : l'app.*

1. **Dev · local** — bump d'une dep : `npm install x@2` pendant le dev.
2. **Automatique** — lockfile écrit : version exacte **+ hash d'intégrité** dans `package-lock.json`.
3. **Git** — push : le lockfile part sur GitHub.
4. **CI** — scan : `npm ci` + osv sur les versions **exactes** du lockfile.
5. **Impact** — `local == CI` garanti : les deux lisent le même lockfile → pas de boucle.

### Canal 2 — Renovate · update de version (routine)

*Déclenché par le bot · décidé par un humain · impact : deps + outillage.*

1. **Renovate · planifié** — lundi : auto-détecte tout écosystème (npm, docker, actions, pip, gradle, cargo…) **+** les 4 binaires épinglés, et propose un bump.
2. **Délai** — maturation 3 j : la release doit vieillir — le temps qu'une vérolée soit repérée.
3. **Renovate** — PR ouverte : minor/patch groupés, les majeures isolées.
4. **CI** — porte : verte ? un bump qui casse reste rouge, ici.
5. **Humain · toi** — merge revu : tu vois passer chaque update — pas d'auto-merge sur la routine.
6. **Impact** — le pin avance : `main` + local se réalignent au `pull`.

### Canal 3 — Renovate · update de sécurité

*Déclenché par une alerte CVE · décidé par la politique · impact : ferme une faille.*

1. **Alerte** — CVE publiée : les **Dependabot alerts** (détection native, gratuite en privé) la lèvent.
2. **Renovate** — security PR : Renovate **lit l'alerte** (`vulnerabilityAlerts`) et ouvre le fix. **Pas de délai** — la sécu bypasse nativement la maturation 3 j.
3. **CI** — porte : verte ?
4. **Auto** — auto-merge (`vulnerabilityAlerts.automerge`) : seule exception au geste humain.
5. **Impact** — faille fermée : sans attendre ta prochaine session.

### En continu — détection & donnée de scan

Les **Dependabot alerts** (détection de CVE, native, gratuite même en privé) tournent en fond — c'est elles que Renovate lit pour le canal 3. En parallèle, la **base OSV** (advisories) et les **packs semgrep** `p/…` sont tirés **à chaque run** de CI, sans PR — déjà toujours à jour. On épingle le **moteur** (pour `local == CI`), pas la **donnée** qu'on veut fraîche. Une faille inconnue reste un zero-day : aucun scanner ne l'attrape, épinglé ou non.

> **Filet** — un bump qui introduit un finding fait échouer **sa propre PR**. CI rouge → pas de merge → `main` n'est jamais cassé pour l'équipe.

---

## Les contrôles — ce que la CI lance sur chaque PR

Chaque outil **auto-détecte son périmètre** et suit la dérive du code sans mémoire humaine (modèle CodeQL). Depuis la bascule full-Renovate, même les mises à jour suivent cette règle : Renovate auto-détecte les écosystèmes, il n'y a plus de liste d'écosystèmes à tenir à la main.

| Outil | Ce qu'il regarde | Détection | Ce qu'il attrape |
|---|---|---|---|
| `CodeQL` | les langages présents | auto | failles de code — *le modèle* |
| `gitleaks` | toute l'histoire git | auto | secrets commités |
| `actionlint` | `.github/workflows/` | auto | erreurs de workflow |
| `zizmor` | `.github/workflows/` | auto | sécu des workflows (politique de pin) |
| `semgrep` | le code · packs curés | quasi-auto | anti-patterns sécu (phase privée) |
| `osv-scanner` | **tous** les manifestes `-r .` | auto ✓ | deps vulnérables (bloque la PR) |
| `Dependabot alerts` | les deps installées | auto (natif) | détection de CVE → **lue par Renovate** |
| `Renovate` | **tous** les manifestes **+** 4 binaires | auto ✓ | deps + outils à bumper (version + sécu) |

---

## Les décisions — qui a décidé quoi, et pourquoi

Le fil de ce chantier, figé pour la reprise.

- **Full-Renovate** *(Romain — ratifié 20/07)* — un seul bot d'update qui auto-détecte tout depuis les manifestes, C++ compris. Dependabot retiré du rôle d'update (il exigeait une liste manuelle par écosystème) ; ses **alerts** restent (détection), Renovate les lit. Preuve empirique : 8/8 managers détectés sans déclaration.
- **Garder le pin** *(Romain)* — ce n'est pas « rester vieux » : c'est ce qui garantit `local == github`. Sans lui, chacun prend « latest » à un instant différent → boucle sans fin.
- **Version = geste humain** *(Romain)* — voir passer les updates. Un projet de 6 mois recevrait sinon des dizaines de bumps invisibles.
- **Sécurité = auto** *(Romain)* — seule exception à l'humain : un fix de CVE doit passer vite. Auto-merge déclaratif (`vulnerabilityAlerts.automerge`), qui bypasse nativement le délai de maturation.
- **Maturation 3 jours** *(Romain)* — le `SHA256` ne protège que le transport, pas une release **vérolée**. Le délai laisse la communauté la repérer. S'applique à la routine, jamais à un fix sécu.
- **semgrep tel quel** *(analyse)* — `--config auto` rallumerait la télémétrie et rendrait les règles imprévisibles, sans gain de sécu. On garde les packs curés + `--metrics=off`.
- **osv `scan -r .`** *(analyse + Romain)* — le scope suit le code au lieu d'être câblé sur npm ; un test local prouvait **7 CVE Python** ratées.

---

## Reste à construire

Chacun sa session : `local == github` pour l'**outillage** (runner local aux versions épinglées + pre-commit gitleaks épinglé) · le **stub build/test universel** (les contrôles-sécu sont déjà agnostiques ; seul le build/test reste à remplir par langage).
