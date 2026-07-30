# Changelog

Ce que ce repo change **pour qui s'en sert** — c'est-à-dire pour qui génère un projet avec
`init-project.sh`, le configure avec `configure-repo.sh`, ou suit le standard et le RUNBOOK.

Le format suit [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> **Pas de versions ici, et c'est voulu.** Ce repo n'a ni tag ni release : il ne se déploie pas,
> il se **lit** et se **joue**. Il n'y a donc qu'une section `Non publié`, qui n'est jamais close.
> Elle porte le **sens** des changements ; le détail vit dans les pull requests, et le récit des
> étapes closes dans `../workspace/archives/`.
>
> ⚠️ **Ce fichier commence le 2026-07-28.** L'antérieur n'a pas été reconstitué — le faire de
> mémoire aurait produit un historique plausible et faux. Pour cette période : les PR et les
> archives font foi.

## [Non publié]

### Ajouté

- **`AGENTS.md` apprend à vérifier le run `push` sur `main` APRÈS un merge** — autre event, donc
  autre run : le vert d'une PR ne dit rien de celui-là, et c'est `main` qui ship. Le contrôle
  n'était prescrit **nulle part** dans le versionné. Il vient avec son piège : la commande déjà
  documentée ne trouve pas ce run-là. ➡️ La règle et la commande vivent dans `AGENTS.md`
  *(gabarit : `templates/repo/AGENTS.md`)*.

- **Le PAT de travail gagne `Administration: read`** *(jamais `write`)* — sans elle, l'assistant ne peut
  **pas vérifier** les réglages qu'un script affirme avoir posés : ni les toggles sécu, ni la branch
  protection **classique** *(invisible dans l'API `rulesets`, et capable de verrouiller `main` pour
  toujours)*. Deux pannes déjà vécues, structurellement indétectables sans cette lecture. Elle ne mute
  rien. ➡️ Dérivation et endpoints : **`docs/github-repo-config.md §2`** ; case à cocher :
  **`docs/RUNBOOK.md §1`**. **Sur un PAT existant, aucune rotation n'est nécessaire** — l'UI édite les
  permissions en place.

- **La skill `new-project` entre dans le repo**, en version **canonique** — `skills/new-project/`, avec
  `~/.claude/skills/new-project` réduit à un **symlink**. Elle déroule le RUNBOOK mais vivait hors de tout
  dépôt : ni versionnée, ni passée par la CI, ni diffable. Elle est à la **racine**, jamais sous
  `templates/` : rien ici ne se duplique dans les projets générés.

### Corrigé

- 🔴 **Le RUNBOOK prescrivait de FERMER une PR d'onboarding Renovate** — or fermer est l'**opt-out
  documenté** du bot. Il affirmait deux faits que le vécu a démentis : « Renovate redémarre de lui-même
  dès qu'il voit le fichier » et « réversible dans les deux sens ». **Le statut `disabled` vit côté Mend**,
  committer `renovate.json` ensuite ne rallume rien, et la réparation demande un **scan manuel au portail**.
  C'est la consigne qui a mis **4 repos sans aucun bot d'update pendant 6 jours** le 14/07. Corrigé en
  « la laisser ouverte et demander », avec la réparation. *(Le fait était déjà rectifié ailleurs — pas ici.)*

- **La skill `new-project` recommandait `gh pr checks`**, formellement interdit dans ce repo *(la permission
  `Checks` n'existe pas dans l'UI des PAT fine-grained)*, et posait encore un **`BACKLOG.md`** que le
  template ne génère plus. Plus 3 dérives : `--type generic` absent, « jamais `Administration` » sans
  `write`, et le package ghcr présenté comme un geste systématique au lieu d'un contrôle conditionnel.

- **Les recettes de PAT annonçaient des permissions PÉRIMÉES — à 4 endroits, dont 2 lus au moment de
  créer le token** *(`configure-repo.sh` avant la saisie masquée, et l'étape 5 de `init-project.sh`)*.
  Elles listaient 4 permissions là où la recette admin en compte 6 : ni `Contents: read` ni
  `Issues: read` n'y avaient été reportées, et **une permission manquante ne lève aucune erreur**.
  Les deux scripts **renvoient** désormais au RUNBOOK au lieu de recopier — une liste corrigée
  aujourd'hui divergerait à la prochaine permission, ce qui est déjà arrivé deux fois de suite.
  ➡️ La recette exécutable vit dans **`docs/RUNBOOK.md` étape 7a**, sa dérivation par endpoint dans
  **`docs/github-repo-config.md` §2** *(où la ligne `Issues: read` manquait aussi)*.

- **« jamais d'`Administration` » disait désormais faux** — le PAT de travail porte `Administration: read`.
  La formule est précisée en **`Administration: write`** partout où elle vivait *(RUNBOOK, standard,
  README, AGENTS, les deux scripts, la checklist)* — le RUNBOOK se contredisait même d'une section à
  l'autre. Et la recette du PAT de travail, dans le standard, ne mentionnait pas la nouvelle permission.

- **Sur un flux à 3 étages, Dependabot aussi visait la PRODUCTION** — et lui, aucune option ne le
  redresse : ses PR de **sécurité** ciblent **toujours** la branche par défaut *(`target-branch` ne
  redirige que les version updates)*. Le filet qui devait protéger `main` la court-circuitait donc,
  en sautant le staging. `configure-repo.sh` ne le **pose plus** sur un flux à 3 étages, et **retire**
  celui déjà en place — mais **seulement si Renovate est prouvé vivant** *(Dependency Dashboard mis à
  jour depuis moins de 14 jours)*. Sans la preuve il **conserve** le filet et **nomme la cause** :
  permission manquante, app non installée, ou bot arrêté. Retirer le filet en misant sur un bot mort
  est la panne de juillet ; un dashboard qui **existe** ne prouve rien, un repo `disabled` garde le
  sien. ➡️ Le pourquoi et le seuil : **standard**, « Qui met à jour les dépendances ».

  🔴 **Deux gestes en découlent, tous deux dans le RUNBOOK :** le **PAT admin éphémère gagne
  `Issues: Read`** *(sans elle la preuve de vie est illisible, et le filet reste posé)* ; et sur un
  projet à 3 étages, **`configure-repo.sh` se rejoue APRÈS l'installation de l'app Renovate** — joué
  avant, il ne peut trouver aucun dashboard.

- **Sur un projet `--staging`, Renovate visait la PRODUCTION.** Faute de `baseBranchPatterns`, le
  bot ciblait la branche **par défaut** : chacune de ses PR — les **sécurité** comprises — atterrissait
  sur `main`, en sautant le host que le troisième étage existe pour valider. `init-project.sh` pose
  désormais la clé sur `develop`, **et seulement quand la branche existe**. ➡️ Le pourquoi, et
  pourquoi la clé est injectée plutôt que portée par le gabarit : bloc `description` de
  `templates/repo/.github/renovate.json`.

### Modifié

- **`configure-repo.sh` ne pose plus `delete-branch-on-merge` sur un repo PRIVÉ à trois étages.**
  Le réglage vise la branche **source** de toute PR mergée — donc `develop` elle-même, au merge
  d'une promotion. En public le ruleset `develop` (règle `deletion`) l'en empêche ; en privé sur
  un plan Free il n'existe aucun ruleset, et la branche disparaissait sans un mot. Ce qu'on perd :
  le nettoyage automatique des `feat/*` — un clic. Le passage en public rétablit le réglage au
  rejeu du script. *(PR #42.)*
- **Les gabarits `ci-node.yml` et `docker-publish.yml` s'appliquent maintenant à un repo dont les
  manifestes ne sont pas à la racine, et à des images qu'un tiers déploie.** `ci-node.yml` refuse
  de passer au vert quand ses étapes npm ont été sautées en silence ; `docker-publish.yml` attache
  un SBOM et une provenance SLSA, et signe l'image avec cosign **par digest**. `configure-repo.sh`
  ouvre les Discussions, sans quoi le lien du template d'issue est un 404. Les deux gabarits
  avertissent qu'une `strategy.matrix` renomme un check REQUIS et bloque la PR pour toujours.
  *(PR #41.)*
- Outils CI épinglés : `zizmor` 1.28.0, `semgrep` 1.171.0, `docker/login-action` v4.5.2. *(PR #40.)*

### Ajouté

- **Ce fichier.** Le standard impose un `CHANGELOG.md` à tout projet généré, et ce repo n'en avait
  pas — un écart à sa propre règle, trouvé en rattrapant celui d'un projet.
