# youtube-auto (plugin) — payload Dispatch

Remplacer `<URL>`. La payload **ne redécrit pas** la procédure : la skill est
la seule source de vérité — zéro dérive entre les deux, et une payload courte.

```
Traite le(s) lien(s) vidéo <URL> de bout en bout avec la skill youtube-auto
(plugin youtube-auto). Suis sa procédure à la lettre, étage par étage : E1
fetch du transcript via Chrome (procédure reference/fetch-transcript.md, ordre
strict, lecture DOM, horodatages conservés), E2 synthèse (subagent
yta-synthese), E2b pertinence (subagent yta-pertinence), E3 livraison Telegram
(digest unique si plusieurs vidéos), E3b archivage Obsidian via le MCP
Obsidian de la session, E3c mise à jour de l'index, E4 teardown. Mode Act
without asking : aucune confirmation, logging par étage dans log.txt,
STOP-on-fail avec notification Telegram (par vidéo en batch).
```

## Checklist pré-lancement

- [ ] Chrome lancé, connecté, YouTube loggé
- [ ] Session en « Act without asking »
- [ ] Plugin youtube-auto installé + skill youtube-synthese disponible
- [ ] `claude-sonnet-5` et `claude-opus-4-8` autorisés pour subagents
- [ ] MCP Telegram `NotifJulokHome` joignable
- [ ] MCP Obsidian de la machine d'exécution joignable
