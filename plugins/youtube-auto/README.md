# youtube-auto (plugin)

Pipeline vidéo Cowork multi-modèle : fetch transcript (panneau natif YouTube,
Chrome) → synthèse (subagent Sonnet 5) → pertinence (subagent Opus 4.8) →
Telegram. Pensé pour Dispatch (async/aveugle).

## Contenu

```
youtube-auto-plugin/
├── .claude-plugin/plugin.json     # manifeste
├── skills/youtube-auto/SKILL.md   # orchestrateur
│   └── reference/payload-dispatch.md
└── agents/
    ├── yta-synthese.md            # model: claude-sonnet-5
    └── yta-pertinence.md          # model: claude-opus-4-8
```

## Dépendances (non bundlées, à avoir dans la session)

- **Claude in Chrome** connecté.
- **Skill `youtube-synthese`** (skill perso) — préchargée par le subagent
  synthèse. Non embarquée ici pour rester DRY ; si tu préfères un plugin
  auto-contenu, copie-la dans `skills/youtube-synthese/`.
- **MCP Telegram `NotifJulokHome`** — non bundlé volontairement (évite de mettre
  le token du bot dans le dossier plugin). Le plugin suppose le MCP présent dans
  la session.

## Installer / développer

Les plugins se développent nativement dans **Claude Code**, puis sont
disponibles en **Cowork** (même moteur).

1. Placer ce dossier dans un dépôt marketplace local, ex. :
   `mon-marketplace/plugins/youtube-auto-plugin/`
   avec un `mon-marketplace/.claude-plugin/marketplace.json` qui le liste.
2. Dev : `/plugin marketplace add ./mon-marketplace` puis
   `/plugin install youtube-auto@mon-marketplace`.
3. Itérer : éditer un fichier, `/reload-plugins`, re-tester `/yta`.

Côté **Cowork** : vérifier le chemin d'install d'un plugin privé (la doc Cowork
décrit surtout l'install en un clic depuis son marketplace). Le chemin sûr
aujourd'hui reste le marketplace local via Claude Code.

## À vérifier au premier run

- `E2b` bien exécuté sur Opus (verdict nettement plus tranché). Si le verdict
  ressemble à du Sonnet, `claude-opus-4-8` n'était pas autorisé pour subagents →
  fallback silencieux.
- Ligne `E4` : si `SKIP action close indisponible` alors qu'un onglet était
  ouvert, l'action de fermeture d'onglet n'est pas exposée à Chrome → fallback à
  étudier (naviguer vers `about:blank`).

## Versionnage

2.0.0 — passage skill → plugin, split modèles (Sonnet synthèse / Opus pertinence).
