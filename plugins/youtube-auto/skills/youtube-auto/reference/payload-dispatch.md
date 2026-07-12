# youtube-auto (plugin) — payload Dispatch

Remplacer `<URL>`. Chrome lancé + connecté + session YouTube loggée. Session en
**« Act without asking »**.

```
Traite le lien vidéo <URL> de bout en bout avec le plugin youtube-auto.

1. (thread principal, Chrome) Ouvre l'URL DANS UN ONGLET NEUF, retiens le handle.
   Récupère le transcript UNIQUEMENT depuis le panneau natif YouTube — aucun
   outil tiers/extension/API/Whisper :
   a) "…afficher plus" pour déplier la description ;
   b) section "Transcription" → "Afficher la transcription" ;
   c) panneau à droite → scrolle jusqu'en bas → extrais sans horodatages
   → transcript.txt. "E1: PASS <nb mots>" ou "E1: FAIL <maillon>" dans log.txt.
   Panneau en échec = FAIL franc, aucun autre outil. Si FAIL → send_notification
   (chat_id 8025225865) + va à l'étape 4.

2. Délègue au subagent yta-synthese (Sonnet 5) : lit transcript.txt, applique
   youtube-synthese → synthese.md. "E2: PASS/FAIL" dans log.txt. FAIL → notif + étape 4.

2b. Délègue au subagent yta-pertinence (Opus 4.8) : lit synthese.md → verdict.md
   (verdict, pour qui, pourquoi, cote /10, TL;DR). Assemble synthese-finale.md =
   synthese.md avec le verdict remplacé par verdict.md. "E2b: PASS/FAIL". FAIL → notif + étape 4.

3. send_document synthese-finale.md (chat_id 8025225865), puis send_notification :
   verdict Opus + TL;DR + nb mots. "E3: PASS/FAIL".

4. Teardown : ferme UNIQUEMENT l'onglet de l'étape 1 (par handle). "E4: PASS/SKIP",
   jamais FAIL. Tourne aussi après un échec.

Mode Act without asking. Aucune confirmation : note dans log.txt et continue.
```

## Checklist pré-lancement

- [ ] Chrome lancé, connecté, YouTube loggé
- [ ] Session en « Act without asking »
- [ ] Plugin youtube-auto installé + skill youtube-synthese disponible
- [ ] `claude-sonnet-5` et `claude-opus-4-8` autorisés pour subagents
- [ ] MCP Telegram `NotifJulokHome` joignable
