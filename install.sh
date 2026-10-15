#!/usr/bin/env bash
# Installiert das Plasma-6-Widget „Claude Buddy“ für den aktuellen Benutzer und trägt die
# Hooks in ~/.claude/settings.json ein (Sicherung: settings.json.bak).
#   ./install.sh             installieren
#   ./install.sh --uninstall Widget und Hooks entfernen
set -euo pipefail
cd "$(dirname "$0")"

id=org.franz.claudebuddy
dest="$HOME/.local/share/plasma/plasmoids/$id"
settings="$HOME/.claude/settings.json"
mode=install
[ "${1:-}" = "--uninstall" ] && mode=uninstall

command -v python3 >/dev/null || { echo "python3 fehlt." >&2; exit 1; }

rm -rf "$dest"
if [ "$mode" = install ]; then
  mkdir -p "$dest"
  cp -r package/. "$dest/"
fi

python3 - "$settings" "$dest/contents/code/buddy.py" "$mode" <<'PY'
import json, shutil, sys
from pathlib import Path
path, script, mode = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
events = {"UserPromptSubmit": 5, "PreToolUse": 5, "PostToolUse": 5, "PostToolUseFailure": 5,
          "PermissionRequest": 5, "Notification": 5, "Stop": 10, "SessionEnd": 5}
text = path.read_text() if path.is_file() else ""
settings = json.loads(text) if text.strip() else {}
hooks = settings.setdefault("hooks", {})
# Alte Buddy-Einträge (auch mit anderem Pfad) entfernen, dann neu eintragen
for name in list(hooks):
    groups = []
    for group in hooks[name]:
        group["hooks"] = [h for h in group.get("hooks", []) if "buddy.py" not in h.get("command", "")]
        if group["hooks"]:
            groups.append(group)
    if groups:
        hooks[name] = groups
    else:
        del hooks[name]
if mode == "install":
    for name, timeout in events.items():
        hooks.setdefault(name, []).append(
            {"hooks": [{"type": "command", "command": f"python3 '{script}' hook", "timeout": timeout}]})
if not hooks:
    del settings["hooks"]
if path.is_file():
    shutil.copy(path, path.with_suffix(".json.bak"))
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
PY

if [ "$mode" = install ]; then
  echo "Installiert. Rechtsklick auf den Desktop > „Miniprogramme hinzufügen“ > „Claude Buddy“."
  echo "Laufende Claude-Code-Sessions neu starten, damit die Hooks greifen."
else
  echo "Entfernt (Widget und Hooks)."
fi
