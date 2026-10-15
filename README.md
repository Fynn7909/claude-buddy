# Claude Buddy

Desktop-Widget für KDE Plasma 6: ein kleines Claude-Maskottchen, das wach wird, solange
[Claude Code](https://claude.com/claude-code) arbeitet, und schläft, wenn nichts läuft. Nach
jeder Antwort fasst es die letzte Antwort in einem Satz zusammen (über `claude -p` mit Haiku,
also über dein eigenes Abo). Ohne laufende Session zeigt es eine Idee des Tages.

## Installieren

Voraussetzungen: KDE Plasma 6, Python 3, Claude Code.

    git clone https://github.com/Fynn7909/claude-buddy.git
    cd claude-buddy
    ./install.sh

Danach Rechtsklick auf den Desktop > „Miniprogramme hinzufügen“ > „Claude Buddy“. Laufende
Claude-Code-Sessions einmal neu starten.

`install.sh` kopiert das Widget nach `~/.local/share/plasma/plasmoids/` und trägt Hooks
(UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest,
Notification, Stop, SessionEnd) in `~/.claude/settings.json` ein. Deine übrigen Einstellungen
bleiben, eine Sicherung liegt in `settings.json.bak`. Erneutes Ausführen aktualisiert, ohne
Hooks doppelt einzutragen.

Entfernen: `./install.sh --uninstall` (Widget und Hooks).

Ein Klick auf den Buddy öffnet [Claude Hub](https://github.com/Fynn7909/claude-hub), falls
installiert.

## Lizenz

GPL-2.0-or-later. Kein offizielles Produkt von Anthropic.
