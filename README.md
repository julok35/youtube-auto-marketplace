# youtube-auto-marketplace

Marketplace Claude Code / Cowork dédié, contenant un plugin :

- **youtube-auto** — pipeline vidéo de bout en bout : fetch du transcript via le
  panneau natif YouTube (Chrome, aucun outil tiers), synthèse déléguée à un
  subagent Sonnet 5, analyse de pertinence déléguée à un subagent Opus 4.8,
  livraison Telegram. Pensé pour l'exécution asynchrone via Dispatch.

## Installer

```
/plugin marketplace add <TON_USER_GITHUB>/youtube-auto-marketplace
/plugin install youtube-auto@youtube-auto-marketplace
```

En dev local, avant tout push :

```
/plugin marketplace add ./youtube-auto-marketplace
/plugin install youtube-auto@youtube-auto-marketplace
```

Détails du plugin, dépendances (Chrome, skill `youtube-synthese`, MCP Telegram)
et points à vérifier au premier run : voir `plugins/youtube-auto/README.md`.

## Structure

```
youtube-auto-marketplace/
├── .claude-plugin/marketplace.json
└── plugins/
    └── youtube-auto/
        ├── .claude-plugin/plugin.json
        ├── skills/youtube-auto/SKILL.md
        └── agents/{yta-synthese,yta-pertinence}.md
```
