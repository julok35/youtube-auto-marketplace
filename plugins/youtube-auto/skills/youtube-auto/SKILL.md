---
name: youtube-auto
description: >
  Pipeline Cowork de bout en bout à partir d'un lien vidéo. Le thread principal
  récupère le transcript via le panneau natif YouTube (Chrome, aucun outil
  tiers — l'IP datacenter de la VM est bloquée par YouTube), délègue la synthèse
  à un subagent Sonnet 5 et l'analyse de pertinence à un subagent Opus 4.8, puis
  pousse le résultat sur Telegram (MCP send-only). Conçu pour l'exécution
  asynchrone/aveugle via Dispatch : logging par étage, STOP-on-fail avec
  notification, aucune demande de confirmation. Use whenever the user gives a
  YouTube (or video) URL and wants the full automated chain — fetch, synthèse,
  pertinence, delivery — especially in Cowork or via Dispatch. Do NOT use if the
  user pastes a transcript directly (that's youtube-synthese). Trigger on:
  "youtube-auto", "/yta", "traite ce lien de bout en bout", "récupère et
  synthétise cette vidéo", "fetch + synthèse + telegram", "pipeline vidéo".
---

# youtube-auto (plugin)

Prendre un lien vidéo, en tirer une synthèse et un verdict de pertinence, et le
livrer sur Telegram — sans intervention. Version plugin, multi-modèle.

## Architecture

Trois exécutants, un modèle chacun par rôle :

- **Thread principal** (modèle de session) — route, **fetch Chrome**,
  orchestration, Telegram, teardown. Le fetch reste ici car Claude in Chrome
  dépend de l'état de session de la conversation principale et n'est pas garanti
  disponible dans un subagent.
- **Subagent `yta-synthese`** (Sonnet 5) — synthèse via `youtube-synthese`.
- **Subagent `yta-pertinence`** (Opus 4.8) — verdict watch-or-skip / cote.

Le passage de contexte entre exécutants se fait **par fichiers sur disque**
(`transcript.txt` → `synthese.md` → `verdict.md`), pas par le contexte
conversationnel : chaque subagent lit son entrée et écrit sa sortie.

## Périmètre & prérequis

**Cowork uniquement.** Les plugins et subagents n'existent pas dans le chat web.

- **Chrome connecté** (Claude in Chrome), lancé côté desktop à l'exécution.
- **Session YouTube loggée** (compte Premium) dans ce Chrome — garantit l'accès
  au panneau « Transcription ».
- **MCP Telegram** : `NotifJulokHome`, send-only, `send_notification` /
  `send_document` (chat_id `8025225865`).
- **Skill `youtube-synthese`** disponible dans la session (préchargée par le
  subagent `yta-synthese`).
- **Modèles `claude-sonnet-5` et `claude-opus-4-8`** dans les modèles autorisés
  pour subagents. Sinon fallback silencieux sur le modèle hérité — à vérifier au
  premier run.
- **Mode « Act without asking »** activé.

## Contraintes dures

- **Panneau natif YouTube = unique source. Aucun outil tiers.** Interdiction
  absolue d'API de transcription hébergée, extension (Glasp/NoteGPT/…), service
  payant, ou Whisper depuis l'audio. Le transcript vient **exclusivement** du
  panneau « Transcription » de la page. Si le panneau est inaccessible →
  `E1: FAIL`, **jamais de substitution par un autre outil**.
- **Jamais de fetch API/CLI depuis la VM.** `youtube-transcript-api`, `yt-dlp`,
  requêtes directes → IP datacenter bloquée par YouTube. Fetch **exclusivement**
  via vraie session navigateur (Chrome), dans le thread principal.
- **Logging par étage obligatoire** dans `log.txt`.
- **STOP-on-fail + notification** : sur échec, notifier le maillon exact par
  Telegram et s'arrêter (après teardown).
- **Zéro confirmation** : une permission requise se note dans `log.txt`, on
  continue.
- **Nettoyage borné** : ne fermer que les onglets ouverts par ce run (par
  handle), jamais un onglet préexistant. Teardown best-effort, non bloquant.
- **Pas d'écriture Obsidian** ici (laisser `knowledge-capture`).

## Procédure

### Étape 0 — Router selon le type de lien

- **YouTube** (`youtube.com/watch`, `youtu.be/…`) → E1 via Chrome. Normaliser en
  `https://www.youtube.com/watch?v=<ID>` ; ignorer `?si=`, `?is=`, `&t=`, `&list=`.
- **Autre plateforme vidéo** → E1 via Chrome best-effort.
- **Page web avec transcript publié** → `web_fetch`, extraire le corps texte.
- **Article texte pur** → hors périmètre : `E1: FAIL page sans transcript`,
  teardown + notif.

### Étape 1 — Fetch du transcript (E1) — thread principal, Chrome

1. Ouvrir l'URL **dans un onglet neuf**, mémoriser son handle.
2. **Déplier la description** (« …afficher plus ») — le bouton transcript
   n'apparaît pas si la description est repliée.
3. Descendre à la section **« Transcription »**, cliquer **« Afficher la
   transcription »**. Ne pas passer par le menu « … » du lecteur.
4. Le panneau « Transcription » s'ouvre à droite. **Scroller jusqu'en bas** pour
   charger toutes les lignes.
5. Extraire le texte, retirer les horodatages → `transcript.txt`.
6. Compter les mots. `E1: PASS <nb mots>` ou `E1: FAIL <maillon>` dans `log.txt`.

Maillons : `Chrome non connecté`, `bouton transcription absent`, `panneau vide`,
`captcha`, `mur connexion`, `captions désactivées`. Échec du panneau = FAIL
franc, **aucun autre outil**.

Si **FAIL** → `send_notification` avec `log.txt`, puis **teardown (Étape 4)** et fin.

### Étape 2 — Synthèse (E2) — subagent yta-synthese (Sonnet 5)

Déléguer au subagent **`yta-synthese`** : il lit `transcript.txt`, applique
`youtube-synthese`, écrit `synthese.md`. Lui passer titre/chaîne/URL si connus.

`E2: PASS` ou `E2: FAIL <cause>` dans `log.txt`.
Si **FAIL** → notif + teardown + fin.

### Étape 2b — Pertinence (E2b) — subagent yta-pertinence (Opus 4.8)

Déléguer au subagent **`yta-pertinence`** : il lit `synthese.md` (et
`transcript.txt` si besoin), écrit `verdict.md` (verdict watch-or-skip, pour qui,
pourquoi, cote /10, TL;DR).

Puis, thread principal : assembler **`synthese-finale.md`** = sections de
`synthese.md` avec le verdict provisoire **remplacé** par le contenu de
`verdict.md`.

`E2b: PASS` ou `E2b: FAIL <cause>` dans `log.txt`.
Si **FAIL** → notif + teardown + fin.

### Étape 3 — Livraison Telegram (E3)

1. `send_document` : `synthese-finale.md`.
2. `send_notification` : verdict d'Opus (`À regarder`/`À survoler`/`À zapper`) +
   TL;DR une ligne + nb mots.
   Ex. : `✅ <titre> — À survoler (6/10) · <TL;DR> · <n> mots`

`E3: PASS` ou `E3: FAIL <cause>` dans `log.txt`.

### Étape 4 — Teardown navigateur

Fermer **uniquement** l'onglet ouvert à l'E1 (par handle). Best-effort, non
bloquant. `E4: PASS` ou `E4: SKIP <raison>` — jamais `E4: FAIL`. S'exécute sur
tous les chemins de sortie, y compris après un STOP.

### Étape 5 — Clôture

Si E1–E3 PASS : fini, tout est sur Telegram, `log.txt` tracé. Rien à ajouter en
dispatché.

## Format du log

Run sain :

```
E1: PASS 3120 mots
E2: PASS
E2b: PASS
E3: PASS
E4: PASS
```

Run cassé (STOP à l'E1, teardown quand même) :

```
E1: FAIL Chrome non connecté
E4: SKIP aucun onglet ouvert
```

## Cas particuliers

- **Subagent qui tombe sur le mauvais modèle** : si `claude-sonnet-5` ou
  `claude-opus-4-8` n'est pas autorisé, le subagent hérite du modèle de session
  sans prévenir. Vérifier au premier run (le rendu Opus est nettement plus
  tranché sur le verdict).
- **Chrome non connecté** : E1 FAIL immédiat — le mode d'échec le plus fréquent.
- **Captcha / mur de connexion** : ne pas résoudre. `E1: FAIL captcha`.
- **Captions désactivées** : pas de panneau → FAIL. Pas de Whisper VM.
- **Transcript en langue tierce** : `yta-synthese` gère (FR par défaut, citations VO).
- **Notif trop longue** : tronquer le TL;DR, le document porte le détail.

## Déclenchement via Dispatch

Payload prête dans `reference/payload-dispatch.md`.
