# Fetch du transcript YouTube — procédure Chrome robuste (E1)

Objectif : le transcript complet **en un seul passage**, sans tâtonnement.
Les échecs viennent presque toujours des mêmes causes — les connaître avant
d'agir évite de les produire.

## Pourquoi ça échoue (à lire AVANT d'agir)

| Symptôme | Cause réelle | Geste correct |
|---|---|---|
| Bouton « Afficher la transcription » introuvable | La description est **repliée** — le bouton n'existe dans le DOM qu'une fois la description dépliée | Cliquer « …plus » (EN : « …more ») d'abord, vérifier que la description longue est visible |
| On cherche dans le menu « ⋯ » du lecteur | Mauvais chemin — le bouton n'y est plus dans l'UI actuelle | Ne **jamais** passer par le lecteur ; uniquement la section « Transcription » de la description |
| Transcript partiel / tronqué | Extraction **visuelle** (screenshots, lecture de ce qui est à l'écran) au lieu du texte du DOM | Une fois le panneau ouvert, **toutes les lignes sont déjà dans le DOM** — lire le contenu textuel de la page, pas l'écran |
| Clics qui tombent dans le vide | Page pas prête : pub en cours, bandeau cookies, player pas chargé | Attendre l'état attendu et le **vérifier** avant chaque action (voir procédure) |
| Bouton au mauvais libellé | UI en anglais vs français | Chercher les deux libellés : « Afficher la transcription » / « Show transcript », « …plus » / « …more » |
| Panneau ouvert mais vide | Chargement en cours ou captions désactivées | Attendre 2 s, relire ; toujours vide → `E1: FAIL panneau vide` |

## Procédure (ordre strict — vérifier l'état APRÈS chaque action, AVANT la suivante)

1. **Ouvrir l'URL normalisée dans un onglet neuf**, mémoriser le handle.
   Attendre le chargement complet : le **titre de la vidéo est visible sous le
   player**. Si bandeau cookies/consentement → le fermer. Si pub pré-roll →
   attendre qu'elle passe (le transcript reste accessible pendant la pub, mais
   les clics sont plus fiables après).
2. **Vérifier la session** : avatar de compte visible en haut à droite.
   Absent → `E1: FAIL mur connexion`.
3. **Déplier la description** : sous le titre, cliquer sur « …plus »
   (« …more ») ou sur le bloc description replié.
   ✅ Vérification : le texte long de la description est maintenant visible.
4. **Ouvrir le panneau** : dans la description dépliée, section
   « Transcription » (« Transcript ») → bouton « Afficher la transcription »
   (« Show transcript »).
   Bouton absent alors que la description est bien dépliée → captions
   désactivées → `E1: FAIL captions désactivées`.
   ✅ Vérification : un panneau « Transcription » est ouvert à droite de la
   vidéo, avec des lignes horodatées.
5. **Extraire par lecture du DOM, en un seul geste.** Point clé : une fois le
   panneau ouvert, l'intégralité des segments est présente dans le DOM du
   panneau — **il n'y a rien à « charger » en scrollant**. Lire le contenu
   textuel de la page et isoler les lignes du panneau (paires
   horodatage + texte). Ne pas prendre de screenshots, ne pas scroller ligne à
   ligne.
   Si — cas rare — l'extraction paraît s'arrêter net en plein milieu d'une
   phrase : scroller le panneau jusqu'en bas **une fois**, puis relire le DOM
   une fois. Pas de boucle.
6. **Nettoyer et écrire** : recoller les segments en lignes lisibles, mais
   **conserver un horodatage `[mm:ss]` en début de chaque ligne** (celui du
   premier segment de la ligne) — ils servent aux liens cliquables
   `watch?v=<ID>&t=<s>s` des « moments à revoir » de la synthèse →
   `RUN_DIR/transcript.txt`. Noter aussi **titre** et **chaîne** (visibles sur
   la page) pour les étapes suivantes.
7. **Contrôle qualité** : compter les mots. Une vidéo de plus de 3 minutes
   donne rarement moins de ~300 mots — en dessous, suspecter une extraction
   partielle et relire le panneau **une seule fois**. Puis logguer :
   `E1: PASS <nb mots>` ou `E1: FAIL <maillon>`.

## Option avancée (si l'exécution JavaScript est disponible dans Chrome)

Extraction one-shot sans aucun clic, depuis les données du player déjà
présentes dans la page (même session, même IP — aucun outil tiers) :

```js
const track = ytInitialPlayerResponse?.captions
  ?.playerCaptionsTracklistRenderer?.captionTracks?.[0];
if (!track) throw "captions désactivées";
const r = await fetch(track.baseUrl + "&fmt=json3");
const j = await r.json();
const mmss = ms => {
  const s = Math.floor(ms / 1000);
  return `[${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}]`;
};
const text = j.events
  .filter(e => e.segs)
  .map(e => mmss(e.tStartMs) + " " +
    e.segs.map(s => s.utf8).join("").replace(/\n+/g, " ").trim())
  .join("\n");
```

`captionTracks` liste toutes les langues ; préférer la piste non-ASR
(`kind !== "asr"`) si disponible, sinon la première. En cas d'échec de cette
option, basculer sur la procédure panneau ci-dessus — pas l'inverse d'un FAIL.

## Maillons de FAIL

`Chrome non connecté` · `mur connexion` · `captcha` · `bouton transcription
absent` · `captions désactivées` · `panneau vide` · `page sans transcript`.

Échec du panneau = FAIL franc, **aucun outil tiers en substitution**.
