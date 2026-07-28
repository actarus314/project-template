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

### Corrigé

- **Sur un projet `--staging`, Renovate visait la PRODUCTION.** Faute de `baseBranchPatterns`, le
  bot cible la branche **par défaut** : chacune de ses PR — les **sécurité** comprises — atterrissait
  donc sur `main`, en sautant le host que le troisième étage existe pour valider. `init-project.sh`
  pose désormais la clé sur `develop`, **et seulement quand la branche existe** : un gabarit qui la
  porterait en dur désignerait une `develop` inexistante sur un projet à deux étages, et Renovate
  sans base valide n'ouvre plus **aucune** PR, en silence. *(Vu en vrai sur `dEURO-dashboard` : sa
  PR #25 `react-router [SECURITY]` visait `main`.)*

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
