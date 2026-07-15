# Workspace — <projet>

Tout ce qui est personnel. **Ce dossier est un repo git à part, LOCAL : il n'a AUCUN remote et ne doit jamais en gagner.**
C'est la mémoire du projet — sans git, toute suppression y serait irréversible.

- `docs/`      : docs de vie — `SUIVI.md` (le CHAUD : reprise-à-froid, il POINTE) · `BACKLOG.md` (travail courant) · `archives/<étape>/` (le FROID : une **synthèse** par étape close — quoi/comment/pourquoi)
                 Le SUIVI **respire** : il grossit pendant une étape, rétrécit à sa clôture (on élague + on synthétise dans `archives/`, jamais un dump).
                 ⚠️ Les **ADR** ne sont PAS ici : ils sont **versionnés** dans `repo/docs/adr/` (immuables, publics).
- `plans/`     : plans d'exécution, roadmap
- `notes/`     : scratch, brouillons, captures de conversation
- `secrets.md` : procédures d'auth, clés API, dates d'expiration — **NE JAMAIS committer**
