# youtube-auto-marketplace — règles de travail

## Versionnage (obligatoire à chaque push)

- **Bump semver à chaque push** qui touche `plugins/youtube-auto/` :
  patch pour un fix/ajustement, minor pour une fonctionnalité, major pour un
  changement incompatible de la procédure.
- Le numéro vit à **deux endroits, toujours identiques** :
  - `.claude-plugin/marketplace.json` → `plugins[].version`
  - `plugins/youtube-auto/.claude-plugin/plugin.json` → `version`
- C'est `plugins[].version` du **marketplace.json** qui déclenche la mise à
  jour côté clients (la valeur est un pin : sans changement de cette chaîne,
  aucun client ne se met à jour, même si le code a changé). Oublier le bump =
  update silencieusement inerte.
- Ajouter l'entrée correspondante dans « Versionnage » de
  `plugins/youtube-auto/README.md`.

## Contrôle de vérité post-update (diff -rq)

Sur la machine cliente, après `/plugin marketplace update youtube-auto-marketplace`
(ou l'auto-update au démarrage) + `/reload-plugins` :

```bash
diff -rq ~/.claude/plugins/cache/youtube-auto-marketplace/youtube-auto/<version>/ \
  <clone-du-repo>/plugins/youtube-auto/
```

Diff vide = la version installée est exactement celle du dépôt. Diff non
vide = l'update n'est pas passé (vérifier le bump de `plugins[].version`,
puis relancer l'update). Ce contrôle est la référence — pas le numéro affiché
par `/plugin`.

## Divers

- Valider les deux JSON avant commit : `python3 -m json.tool <fichier>`.
- La skill `SKILL.md` est l'unique source de vérité de la procédure ; la
  payload Dispatch (`reference/payload-dispatch.md`) ne doit jamais la
  redécrire.
