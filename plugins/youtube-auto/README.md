# youtube-auto (plugin)

Pipeline vidéo Cowork multi-modèle : fetch transcript (panneau natif YouTube,
Chrome) → synthèse (subagent Sonnet 5) → pertinence (subagent Opus 4.8) →
Telegram + archivage Obsidian. Pensé pour Dispatch (async/aveugle).

## Contenu

```
youtube-auto-plugin/
├── .claude-plugin/plugin.json     # manifeste
├── skills/youtube-auto/SKILL.md   # orchestrateur
│   └── reference/
│       ├── fetch-transcript.md    # procédure Chrome robuste (E1)
│       └── payload-dispatch.md
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
- **MCP Obsidian** — celui installé sur la machine d'exécution, quel que soit
  son nom de serveur. Aucun chemin de vault en dur dans le plugin : seuls des
  chemins relatifs au vault (`YouTube/…`) sont utilisés. MCP absent →
  l'archivage `E3b`/`E3c` échoue proprement (non bloquant) et le reste du
  pipeline tourne.

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

Semver bumpé à chaque push, en miroir dans `plugin.json` et dans
`plugins[].version` du `marketplace.json` (ce dernier déclenche l'update
clients). Contrôle de vérité post-update : `diff -rq` entre le cache local et
le dépôt — voir le README racine.

- 2.2.2 — retrait de l'option JS `captionTracks` (retex : YouTube renvoie un
  JSON vide) ; le panneau natif + lecture DOM est l'unique voie d'extraction,
  la voie morte est documentée pour ne pas être retentée.
- 2.2.1 — semver porté par `marketplace.json` (`plugins[].version`),
  procédure d'auto-update et contrôle de vérité `diff -rq` documentés,
  règles de release dans `CLAUDE.md`.
- 2.2.0 — archivage Obsidian via le MCP de la machine d'exécution (zéro chemin
  en dur), mode batch/playlist avec digest Telegram trié par cote (cas nominal
  mono-vidéo inchangé), index Obsidian auto-entretenu (E3c), « moments à
  revoir » cliquables (`&t=<s>s`, horodatages conservés à l'E1).
- 2.1.0 — archivage Obsidian systématique (E3b), procédure de fetch transcript
  robuste (`reference/fetch-transcript.md`, lecture DOM one-shot), payload
  Dispatch dé-dupliquée (la skill est l'unique source de vérité), assemblage
  du verdict par bloc balisé (plus de régénération du document), dossier de
  travail par run (`yta-<videoID>/`).
- 2.0.0 — passage skill → plugin, split modèles (Sonnet synthèse / Opus
  pertinence).
