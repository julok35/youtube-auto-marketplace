---
name: youtube-auto
description: >
  Pipeline vidéo de bout en bout depuis une URL : fetch du transcript via
  Chrome (panneau natif YouTube), synthèse (subagent Sonnet 5), verdict de
  pertinence (subagent Opus 4.8), livraison Telegram + archivage Obsidian.
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
| `VAULT_PATH` | Dossier du vault Obsidian pour l'archivage, ex. `~/Obsidian/<vault>/YouTube/`. **À définir avant le premier run** ; non défini → `E3b: FAIL vault non configuré` (non bloquant). |
| `RUN_DIR` | `yta-<videoID>/` (dossier de travail du run, créé à l'E1 — évite toute collision entre runs) |

Fichiers du run, tous dans `RUN_DIR` : `transcript.txt` → `synthese.md` →
`verdict.md` → `synthese-finale.md`, plus `log.txt`.

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
- **Skill `youtube-synthese`** disponible (préchargée par `yta-synthese`).
- **Modèles `claude-sonnet-5` et `claude-opus-4-8`** autorisés pour subagents
  (sinon fallback silencieux sur le modèle hérité — vérifier au premier run).
- **Mode « Act without asking »** activé.

## Contraintes dures

- **Extraction exclusivement via la session Chrome.** Source primaire : le
  panneau natif « Transcription » de la page. Toléré : les données du player
  déjà présentes dans la page (même session, même IP). **Interdit** : tout
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

### Étape 0 — Router selon le type de lien

- **YouTube** (`youtube.com/watch`, `youtu.be/…`) → E1 via Chrome. Normaliser
  en `https://www.youtube.com/watch?v=<ID>` ; ignorer `?si=`, `&t=`, `&list=`.
- **Autre plateforme vidéo** → E1 via Chrome best-effort.
- **Page web avec transcript publié** → `web_fetch`, extraire le corps texte.
- **Article texte pur** → hors périmètre : `E1: FAIL page sans transcript`,
  teardown + notif.

### Étape 1 — Fetch du transcript (E1) — thread principal, Chrome

Suivre **à la lettre** `reference/fetch-transcript.md` (ordre strict,
vérification d'état après chaque action, extraction par lecture DOM — pas de
screenshots). Sortie : `transcript.txt` + titre + chaîne.

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

1. `send_document` : `synthese-finale.md`.
2. `send_notification` : verdict d'Opus (`À regarder`/`À survoler`/`À zapper`)
   + TL;DR une ligne + nb mots.
   Ex. : `✅ <titre> — À survoler (6/10) · <TL;DR> · <n> mots`

`E3: PASS` ou `E3: FAIL <cause>`.

### Étape 3b — Archivage Obsidian (E3b) — systématique

Écrire la note dans le vault (`VAULT_PATH`), fichier
`YYYY-MM-DD <titre>.md` (titre nettoyé des caractères interdits ; en cas de
collision, suffixer ` (2)`), contenant :

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

Créer `VAULT_PATH` s'il n'existe pas. **Non bloquant** : `E3b: PASS <chemin>`
ou `E3b: FAIL <cause>` (vault non configuré, chemin inaccessible…) — sur FAIL,
l'indiquer dans la notification Telegram (ou en envoyer une courte), puis
continuer.

### Étape 4 — Teardown navigateur

Fermer **uniquement** l'onglet ouvert à l'E1 (par handle). Best-effort, non
bloquant. `E4: PASS` ou `E4: SKIP <raison>` — jamais `E4: FAIL`. S'exécute sur
tous les chemins de sortie, y compris après un STOP.

### Étape 5 — Clôture

Si E1–E3b PASS : fini, tout est sur Telegram et dans Obsidian, `log.txt`
tracé. Rien à ajouter en dispatché.

## Format du log

Run sain :

```
E1: PASS 3120 mots
E2: PASS
E2b: PASS
E3: PASS
E3b: PASS ~/Obsidian/Main/YouTube/2026-07-13 Titre.md
E4: PASS
```

Run cassé (STOP à l'E1, teardown quand même) :

```
E1: FAIL Chrome non connecté
E4: SKIP aucun onglet ouvert
```

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
