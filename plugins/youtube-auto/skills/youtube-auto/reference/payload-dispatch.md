# youtube-auto (plugin) — payload Dispatch

Remplacer `<URL>`. La payload **ne redécrit pas** la procédure : la skill est
la seule source de vérité — zéro dérive entre les deux, et une payload courte.

```
Traite le lien vidéo <URL> de bout en bout avec la skill youtube-auto (plugin
youtube-auto). Suis sa procédure à la lettre, étage par étage : E1 fetch du
transcript via Chrome (procédure reference/fetch-transcript.md, ordre strict,
lecture DOM), E2 synthèse (subagent yta-synthese), E2b pertinence (subagent
yta-pertinence), E3 livraison Telegram, E3b archivage Obsidian, E4 teardown.
Mode Act without asking : aucune confirmation, logging par étage dans log.txt,
STOP-on-fail avec notification Telegram.
```

## Checklist pré-lancement

- [ ] Chrome lancé, connecté, YouTube loggé
- [ ] Session en « Act without asking »
- [ ] Plugin youtube-auto installé + skill youtube-synthese disponible
- [ ] `claude-sonnet-5` et `claude-opus-4-8` autorisés pour subagents
- [ ] MCP Telegram `NotifJulokHome` joignable
- [ ] `VAULT_PATH` Obsidian défini dans la section Configuration de la skill
