pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Paleta do pywal (~/.cache/wal/colors.json) — recarrega sozinha quando o
// wallpaper muda. Todo o resto do shell lê cor daqui, nunca hardcoded.
Singleton {
    id: root

    property var wal: ({})

    function pick(n, fallback) { return wal.colors?.["color" + n] ?? fallback }
    // Qt.lighter(c, 1) converte string ("white") em color, senão .r/.g/.b viram undefined
    function alpha(c, a) { const k = Qt.lighter(c, 1.0); return Qt.rgba(k.r, k.g, k.b, a) }

    readonly property color bg: wal.special?.background ?? "#0c0707"
    readonly property color fg: wal.special?.foreground ?? "#eaa09e"
    readonly property color accent: pick(4, "#f71019")
    readonly property color accentSoft: pick(6, "#9a5757")
    readonly property color muted: pick(8, "#a3706e")

    // Dynamic Island: preto puro como no OLED, conteúdo em branco
    readonly property color island: "#000000"
    readonly property color islandFg: "#f5f5f7"
    readonly property color islandMuted: "#8e8e93"
    readonly property color orange: "#ff9f0a"

    readonly property string font: "SF Pro Display"
    readonly property string monoFont: "JetBrainsMono Nerd Font"
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    readonly property int barHeight: 36
    readonly property int radius: 18
    readonly property int animFast: 140
    readonly property int animMed: 240

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.wal = JSON.parse(text()) } catch (e) { console.warn("Theme: colors.json inválido", e) }
        }
    }
}
