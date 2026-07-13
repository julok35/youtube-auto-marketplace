# youtube-auto-marketplace

Marketplace Claude Code / Cowork dédié, contenant un plugin :

- **youtube-auto** — pipeline vidéo de bout en bout (une vidéo, ou batch /
  playlist avec digest trié par cote) : fetch du transcript via le panneau
  natif YouTube (Chrome, aucun outil tiers), synthèse déléguée à un subagent
  Sonnet 5 avec « moments à revoir » cliquables, analyse de pertinence
  déléguée à un subagent Opus 4.8, livraison Telegram, archivage et index
  auto-entretenu dans le vault Obsidian via son MCP. Pensé pour l'exécution
  asynchrone via Dispatch.

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

Détails du plugin, dépendances (Chrome, skill `youtube-synthese`, MCP Telegram,
MCP Obsidian) et points à vérifier au premier run : voir
`plugins/youtube-auto/README.md`.

## Mises à jour

Le semver est porté par `plugins[].version` dans
`.claude-plugin/marketplace.json` (miroir dans `plugin.json`) et **bumpé à
chaque push** : c'est ce champ qui déclenche l'update côté clients.

**Activer l'auto-update** (les marketplaces tiers sont désactivés par défaut) —
au choix :

- UI : `/plugin` → onglet **Marketplaces** → `youtube-auto-marketplace` →
  **Enable auto-update**. Les plugins se mettent alors à jour au démarrage de
  Claude Code / Cowork (puis `/reload-plugins` si demandé).
- `settings.json` :

  ```json
  {
    "extraKnownMarketplaces": {
      "youtube-auto-marketplace": {
        "source": { "source": "github", "repo": "julok35/youtube-auto-marketplace" },
        "autoUpdate": true
      }
    }
  }
  ```

- Manuel : `/plugin marketplace update youtube-auto-marketplace`.

**Contrôle de vérité** — le juge de paix n'est pas le numéro affiché mais le
diff entre le plugin installé (cache local) et le dépôt :

```bash
diff -rq ~/.claude/plugins/cache/youtube-auto-marketplace/youtube-auto/<version>/ \
  plugins/youtube-auto/
```

Diff vide = version installée conforme au dépôt. Diff non vide = update non
appliqué (bump de `plugins[].version` oublié, ou update/reload pas encore
passé).

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
