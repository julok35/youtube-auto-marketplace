#!/usr/bin/env bash
# Hook PreToolUse(Skill) — contrôle de version youtube-auto (E0).
# Bloque le lancement de la skill si la version installée (plugin.json du
# cache) diffère de plugins[].version publiée sur main. Fail-open : toute
# erreur (réseau, parsing, python3 absent) laisse le run se dérouler.
set -u

MARKETPLACE_RAW="https://raw.githubusercontent.com/julok35/youtube-auto-marketplace/main/.claude-plugin/marketplace.json"
OVERRIDE_SENTINEL="/tmp/yta-version-override"

# Échappatoires : env, ou sentinelle one-shot posée après choix « continuer ».
[ "${YTA_SKIP_VERSION_CHECK:-0}" = "1" ] && exit 0
if [ -f "$OVERRIDE_SENTINEL" ]; then
  rm -f "$OVERRIDE_SENTINEL"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || exit 0

# Ne filtrer que les invocations de la skill youtube-auto.
SKILL="$(python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("skill", ""))
except Exception:
    print("")
' 2>/dev/null)"
case "$SKILL" in
  youtube-auto | *:youtube-auto) ;;
  *) exit 0 ;;
esac

LOCAL="$(python3 -c '
import json, sys
print(json.load(open(sys.argv[1]))["version"])
' "${CLAUDE_PLUGIN_ROOT:-.}/.claude-plugin/plugin.json" 2>/dev/null)"
[ -n "$LOCAL" ] || exit 0

REMOTE="$(curl -fsSL --max-time 5 "$MARKETPLACE_RAW" 2>/dev/null | python3 -c '
import json, sys
plugins = json.load(sys.stdin)["plugins"]
print(next(p["version"] for p in plugins if p["name"] == "youtube-auto"))
' 2>/dev/null)"
[ -n "$REMOTE" ] || exit 0

[ "$LOCAL" = "$REMOTE" ] && exit 0

cat >&2 <<EOF
E0: STALE — version installée ${LOCAL}, version publiée ${REMOTE}.
NE PAS dérouler la procédure youtube-auto maintenant. Conduite à tenir :
- Session interactive : poser le choix à l'utilisateur (AskUserQuestion) :
  1) « Mettre à jour puis reprendre » — il exécute
     /plugin marketplace update youtube-auto-marketplace puis /reload-plugins,
     puis relance sa demande. Ne rien faire d'autre.
  2) « Continuer avec ${LOCAL} » — créer la sentinelle
     ${OVERRIDE_SENTINEL} (touch), relancer la skill (le hook la consomme),
     et logger « E0: OVERRIDE ${LOCAL} (publiée ${REMOTE}) » en tête de log.txt.
- Run Dispatch (aveugle, aucun utilisateur) : send_notification Telegram
  « ⚠️ yta E0: STALE ${LOCAL} → ${REMOTE} — run stoppé, mettre à jour puis
  relancer », puis fin (rien d'ouvert, pas de teardown).
EOF
exit 2
