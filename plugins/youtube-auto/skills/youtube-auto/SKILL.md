---
name: youtube-auto
description: >
  Pipeline vidéo de bout en bout depuis une ou plusieurs URLs (batch/playlist
  supporté, cas nominal = une vidéo) : fetch du transcript via Chrome (panneau
  natif YouTube), synthèse (subagent Sonnet 5), verdict de pertinence
  (subagent Opus 4.8), livraison Telegram + archivage et index Obsidian (MCP).
  Asynchrone/aveugle (Dispatch) : logging par étage, STOP-on-fail avec
  notification, zéro confirmation. Use whenever the user gives a YouTube (or
  video) URL and wants the full automated chain. Do NOT use if the user pastes
  a transcript directly (that's youtube-synthese). Trigger on: "youtube-auto",
  "/yta", "traite ce lien de bout en bout", "récupère et synthétise cette
  vidéo".
---

# youtube-auto (plugin)

Prendre un lien vidéo, en tirer une synthèse et un verdict de pertinence,
livrer sur Telegram et archiver dans Obsidian — sans intervention.

## Configuration (source unique de vérité)

| Clé | Valeur |
|---|---|
| `CHAT_ID` | `8025225865` — MCP Telegram `NotifJulokHome` (send-only : `send_notification`, `send_document`) |
| MCP Obsidian | Le serveur MCP Obsidian installé sur la machine d'exécution (découvrir ses outils dans la session : lecture/écriture de notes du vault). **Aucun chemin de vault en dur** — seuls des chemins *relatifs au vault* sont utilisés. MCP absent → `E3b: FAIL MCP Obsidian indisponible` (non bloquant). |
| `NOTES_DIR` | `YouTube/` — dossier **relatif au vault** où vont les notes d'analyse |
| `INDEX_NOTE` | `YouTube/YouTube - Index.md` — index auto-entretenu, trié par cote |
| `RUN_DIR` | `yta-<videoID>/` (dossier de travail, créé à l'E1 — un par vidéo, y compris en batch : aucune collision) |
| `BATCH_MAX` | 10 vidéos max par batch ; au-delà, tronquer et le dire dans le digest |

Fichiers du run, tous dans `RUN_DIR` : `transcript.txt` → `synthese.md` →
`verdict.md` → `synthese-finale.md`, plus `log.txt` (unique, partagé par tout
le batch le cas échéant, lignes préfixées `[<videoID>]` si plusieurs vidéos).

## Architecture

Trois exécutants, un modèle chacun par rôle :

- **Thread principal** (modèle de session) — route, **fetch Chrome**,
  orchestration, Telegram, Obsidian, teardown. Le fetch reste ici car Claude
  in Chrome dépend de l'état de session de la conversation principale.
- **Subagent `yta-synthese`** (Sonnet 5) — synthèse via `youtube-synthese`.
- **Subagent `yta-pertinence`** (Opus 4.8) — verdict watch-or-skip / cote.

Le passage de contexte entre exécutants se fait **par fichiers sur disque**,
pas par le contexte conversationnel : chaque subagent lit son entrée et écrit
sa sortie.

## Périmètre & prérequis

**Cowork uniquement.** Les plugins et subagents n'existent pas dans le chat web.

- **Chrome connecté** (Claude in Chrome), session **YouTube loggée** (Premium).
- **MCP Telegram** `NotifJulokHome` joignable.
- **MCP Obsidian** joignable (celui de la machine d'exécution, quel que soit
  son nom de serveur — l'identifier au run par ses outils de vault).
- **Skill `youtube-synthese`** disponible (préchargée par `yta-synthese`).
- **Modèles `claude-sonnet-5` et `claude-opus-4-8`** autorisés pour subagents
  (sinon fallback silencieux sur le modèle hérité — vérifier au premier run).
- **Mode « Act without asking »** activé.

## Contraintes dures

- **Extraction exclusivement via la session Chrome.** Source unique : le
  panneau natif « Transcription » de la page, lu dans le DOM. L'extraction JS
  one-shot via `captionTracks` est une **voie morte** (YouTube renvoie un JSON
  vide — voir `reference/fetch-transcript.md`). **Interdit** : tout
  outil tiers (API de transcription hébergée, extension, service payant,
  Whisper), et tout fetch API/CLI depuis la VM (`youtube-transcript-api`,
  `yt-dlp`, requêtes directes → IP datacenter bloquée). Panneau inaccessible →
  `E1: FAIL`, jamais de substitution par un outil tiers.
- **Logging par étage obligatoire** dans `log.txt`.
- **STOP-on-fail + notification** : sur échec bloquant, notifier le maillon
  exact par Telegram et s'arrêter (après teardown).
- **Zéro confirmation** : une permission requise se note dans `log.txt`, on
  continue.
- **Nettoyage borné** : ne fermer que les onglets ouverts par ce run (par
  handle), jamais un onglet préexistant. Teardown best-effort, non bloquant.

## Procédure

### Étape 0 — Contrôle de version (E0) — hook, automatique

Un hook `PreToolUse` embarqué dans le plugin (`hooks/check-version.sh`)
s'exécute **avant le chargement de la skill** : il compare la version
installée (`plugin.json` du cache) à `plugins[].version` du `marketplace.json`
publié sur `main`. Aligné → il est muet, rien à logger. Erreur réseau ou de
parsing → **fail-open**, le run se déroule normalement.

Si les versions diffèrent, le hook **bloque le lancement** avec
`E0: STALE <installée> → <publiée>`. Conduite à tenir :

- **Session interactive** : poser le choix à l'utilisateur
  (`AskUserQuestion`), deux options :
  1. **Mettre à jour puis reprendre** — l'utilisateur exécute
     `/plugin marketplace update youtube-auto-marketplace` puis
     `/reload-plugins`, et relance sa demande. Ne rien dérouler d'autre.
  2. **Continuer avec la version installée** — créer la sentinelle
     `/tmp/yta-version-override` (`touch` ; one-shot, le hook la consomme),
     relancer la skill, et logger
     `E0: OVERRIDE <installée> (publiée <publiée>)` en tête de `log.txt`.
- **Run Dispatch (aveugle)** : aucun choix possible → `send_notification`
  « ⚠️ yta E0: STALE <installée> → <publiée> — run stoppé, mettre à jour puis
  relancer », puis fin (rien d'ouvert, pas de teardown).

### Étape 0b — Router selon le type de lien (mono ou batch)

- **YouTube** (`youtube.com/watch`, `youtu.be/…`) → E1 via Chrome. Normaliser
  en `https://www.youtube.com/watch?v=<ID>` ; ignorer `?si=`, `&t=`, `&list=`.
- **Autre plateforme vidéo** → E1 via Chrome best-effort.
- **Page web avec transcript publié** → `web_fetch`, extraire le corps texte.
- **Article texte pur** → hors périmètre : `E1: FAIL page sans transcript`,
  teardown + notif.

**Batch** — le cas nominal reste **une seule vidéo** et ne change rien à la
procédure. Si l'entrée contient **plusieurs URLs**, ou une **playlist**
(`youtube.com/playlist?list=…`) :

1. Playlist : l'ouvrir dans Chrome, collecter les URLs des vidéos (max
   `BATCH_MAX`, tronquer au-delà et le noter).
2. Dérouler **E1 → E2b → E3b/E3c séquentiellement pour chaque vidéo** (un
   `RUN_DIR` chacune). L'échec d'une vidéo se logue et se signale dans le
   digest, mais **ne stoppe pas les suivantes** (STOP-on-fail vaut par vidéo).
3. En E3, remplacer les notifications individuelles par un **digest unique**
   (voir E3). Les `send_document` restent par vidéo.

### Étape 1 — Fetch du transcript (E1) — thread principal, Chrome

Suivre **à la lettre** `reference/fetch-transcript.md` (ordre strict,
vérification d'état après chaque action, extraction par lecture DOM — pas de
screenshots). Sortie : `transcript.txt` — **horodatages `[mm:ss]` conservés en
début de ligne** (ils servent aux liens cliquables des « moments à revoir ») —
plus titre + chaîne.

`E1: PASS <nb mots>` ou `E1: FAIL <maillon>` dans `log.txt`.
Si **FAIL** → `send_notification` avec le contenu de `log.txt`, puis
**teardown (Étape 4)** et fin.

### Étape 2 — Synthèse (E2) — subagent yta-synthese (Sonnet 5)

Déléguer au subagent **`yta-synthese`** en lui passant le chemin `RUN_DIR` et
titre/chaîne/URL : il lit `transcript.txt`, applique `youtube-synthese`, écrit
`synthese.md` avec le verdict provisoire balisé entre
`<!-- YTA:VERDICT:START -->` et `<!-- YTA:VERDICT:END -->`.

`E2: PASS` ou `E2: FAIL <cause>`. Si **FAIL** → notif + teardown + fin.

### Étape 2b — Pertinence (E2b) — subagent yta-pertinence (Opus 4.8)

Déléguer au subagent **`yta-pertinence`** (lui passer `RUN_DIR`) : il lit
`synthese.md` (et `transcript.txt` si besoin), écrit `verdict.md`.

Puis, thread principal : produire **`synthese-finale.md`** = copie de
`synthese.md` où le bloc entre les balises `YTA:VERDICT` est **remplacé** par
le contenu de `verdict.md` (remplacement mécanique du bloc balisé — ne pas
régénérer le document).

`E2b: PASS` ou `E2b: FAIL <cause>`. Si **FAIL** → notif + teardown + fin.

### Étape 3 — Livraison Telegram (E3)

1. `send_document` : `synthese-finale.md` (par vidéo, y compris en batch).
2. `send_notification` : verdict d'Opus (`À regarder`/`À survoler`/`À zapper`)
   + TL;DR une ligne + nb mots.
   Ex. : `✅ <titre> — À survoler (6/10) · <TL;DR> · <n> mots`

**En batch** : pas de notification par vidéo — un **digest unique** en fin de
lot, vidéos **triées par cote décroissante**, une ligne chacune
(`<cote>/10 <verdict> — <titre> · <TL;DR court>`), échecs listés en queue
(`❌ <titre ou URL> — <maillon>`).

`E3: PASS` ou `E3: FAIL <cause>`.

### Étape 3b — Archivage Obsidian (E3b) — systématique, via MCP

Écrire la note **avec les outils du MCP Obsidian de la session** (jamais de
chemin machine en dur — uniquement des chemins relatifs au vault), dans
`NOTES_DIR`, fichier `YYYY-MM-DD <titre>.md` (titre nettoyé des caractères
interdits ; en cas de collision, suffixer ` (2)`), contenant :

```markdown
---
type: youtube
titre: "<titre>"
chaine: "<chaîne>"
url: https://www.youtube.com/watch?v=<ID>
date: <YYYY-MM-DD>
verdict: <À regarder|À survoler|À zapper>
cote: <n>/10
tags: [youtube, yta]
---

🔗 [Voir la vidéo](https://www.youtube.com/watch?v=<ID>)

<contenu intégral de synthese-finale.md>
```

**Non bloquant** : `E3b: PASS <NOTES_DIR/fichier>` ou `E3b: FAIL <cause>`
(MCP Obsidian indisponible, écriture refusée…) — sur FAIL, l'indiquer dans la
notification Telegram, puis continuer.

### Étape 3c — Index Obsidian (E3c) — auto-entretenu

Mettre à jour `INDEX_NOTE` via le MCP Obsidian : la lire (la créer si absente
avec l'en-tête ci-dessous), insérer la ligne de la vidéo **en gardant le
tableau trié par cote décroissante**, réécrire.

```markdown
# YouTube — Index

Trié par cote (rapport signal/temps). Généré par youtube-auto.

| Cote | Verdict | Vidéo | Chaîne | Date |
|---|---|---|---|---|
| 8/10 | À regarder | [[2026-07-13 Titre\|Titre]] · [▶︎](https://www.youtube.com/watch?v=<ID>) | Chaîne | 2026-07-13 |
```

Le lien `[[…]]` pointe vers la note d'analyse (E3b), `▶︎` vers la vidéo. Si la
vidéo figure déjà dans l'index (même ID), remplacer sa ligne au lieu de
dupliquer. **Non bloquant** : `E3c: PASS` ou `E3c: FAIL <cause>`.

### Étape 4 — Teardown navigateur

Fermer **uniquement** les onglets ouverts par ce run (par handle — en batch,
fermer l'onglet d'une vidéo dès sa fin de traitement, plus l'onglet playlist).
Best-effort, non bloquant. `E4: PASS` ou `E4: SKIP <raison>` — jamais
`E4: FAIL`. S'exécute sur tous les chemins de sortie, y compris après un STOP.

### Étape 5 — Clôture

Si E1–E3c PASS : fini, tout est sur Telegram et dans Obsidian (note + index),
`log.txt` tracé. Rien à ajouter en dispatché.

## Format du log

Run sain (`E0` n'apparaît que si le contrôle de version a bloqué puis été
outrepassé — sinon aucune ligne E0) :

```
E1: PASS 3120 mots
E2: PASS
E2b: PASS
E3: PASS
E3b: PASS YouTube/2026-07-13 Titre.md
E3c: PASS
E4: PASS
```

Run cassé (STOP à l'E1, teardown quand même) :

```
E1: FAIL Chrome non connecté
E4: SKIP aucun onglet ouvert
```

Batch : mêmes lignes, préfixées `[<videoID>]` ; l'échec d'une vidéo n'arrête
pas les autres et apparaît dans le digest E3.

## Cas particuliers

- **Subagent sur le mauvais modèle** : si `claude-sonnet-5` ou
  `claude-opus-4-8` n'est pas autorisé, fallback silencieux sur le modèle de
  session. Vérifier au premier run (le rendu Opus est nettement plus tranché).
- **Chrome non connecté** : E1 FAIL immédiat — le mode d'échec le plus fréquent.
- **Captcha / mur de connexion** : ne pas résoudre. `E1: FAIL captcha`.
- **Captions désactivées** : pas de panneau → FAIL. Pas de Whisper VM.
- **Transcript en langue tierce** : `yta-synthese` gère (FR par défaut,
  citations VO).
- **Notif trop longue** : tronquer le TL;DR, le document porte le détail.

## Déclenchement via Dispatch

Payload prête dans `reference/payload-dispatch.md`.
