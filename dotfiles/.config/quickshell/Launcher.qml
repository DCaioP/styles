import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// Busca/launcher. Abre no monitor focado.
//   texto      → apps (fuzzy + mais usados primeiro)
//   = 2*(3+4)  → calculadora
//   > comando  → roda no shell
//   timer 5m   → timer na Dynamic Island
// ↑/↓ ou Ctrl+J/K navegam, Enter executa, Esc fecha.
Scope {
    id: root

    property string query: ""
    property var usage: ({})

    function toggle() { Globals.launcherOpen = !Globals.launcherOpen }

    // atalho global sem spawnar processo: bind = SUPER, D, global, quickshell:launcher
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Abre/fecha a busca"
        onPressed: root.toggle()
    }

    // fallback por IPC: qs ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
    }

    // contagem de uso por app, pra ordenar os mais abertos primeiro
    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/launcher-usage.json"
        blockLoading: true
        onLoaded: { try { root.usage = JSON.parse(text()) } catch (e) { root.usage = {} } }
    }

    function bump(id) {
        const u = Object.assign({}, usage)
        u[id] = (u[id] ?? 0) + 1
        usage = u
        usageFile.setText(JSON.stringify(u))
    }

    // fuzzy por subsequência: bônus p/ início de palavra e letras seguidas
    function fuzzy(needle, hay) {
        if (!hay) return 0
        hay = hay.toLowerCase()
        if (hay.startsWith(needle)) return 1000 - hay.length
        const idx = hay.indexOf(needle)
        if (idx >= 0) return 600 - idx
        let score = 0, hi = 0, streak = 0
        for (const ch of needle) {
            const found = hay.indexOf(ch, hi)
            if (found < 0) return 0
            streak = found === hi ? streak + 1 : 0
            score += 10 + streak * 8 + ((found === 0 || " -_.".includes(hay[found - 1])) ? 25 : 0)
            hi = found + 1
        }
        return score
    }

    readonly property var results: {
        const q = query.trim()

        if (q.startsWith("=")) {
            const expr = q.slice(1).trim()
            if (/^[\d\s+\-*/().,%^]+$/.test(expr) && expr !== "") {
                try {
                    const v = Function(`"use strict"; return (${expr.replace(/\^/g, "**").replace(/,/g, ".")})`)()
                    if (isFinite(v)) return [{ kind: "calc", name: String(+v.toFixed(10)), comment: expr + "  ·  Enter copia", icon: "accessories-calculator" }]
                } catch (e) {}
            }
            return []
        }

        const t = q.match(/^timer\s+(\d+)\s*(s|m|h)?$/i)
        if (t) {
            const sec = +t[1] * ({ s: 1, m: 60, h: 3600 }[(t[2] ?? "m").toLowerCase()])
            return [{ kind: "timer", seconds: sec, name: "Timer de " + Globals.fmt(sec), comment: "Inicia na Dynamic Island", icon: "alarm-symbolic" }]
        }

        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim()
            return cmd ? [{ kind: "cmd", name: cmd, comment: "Rodar no shell", icon: "utilities-terminal" }] : []
        }

        const apps = DesktopEntries.applications.values
        const needle = q.toLowerCase()
        return apps
            .map(e => {
                const s = needle === "" ? 1 : Math.max(
                    fuzzy(needle, e.name),
                    fuzzy(needle, e.genericName) * 0.6,
                    fuzzy(needle, (e.keywords ?? []).join(" ")) * 0.5,
                    fuzzy(needle, e.id) * 0.4)
                return { kind: "app", entry: e, name: e.name, comment: e.comment || e.genericName, icon: e.icon,
                         score: s > 0 ? s + Math.log2(1 + (usage[e.id] ?? 0)) * 60 : 0 }
            })
            .filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score || a.name.localeCompare(b.name))
            .slice(0, 50)
    }

    function activate(r) {
        if (!r) return
        if (r.kind === "app") { bump(r.entry.id); r.entry.execute() }
        else if (r.kind === "cmd") Quickshell.execDetached(["sh", "-c", r.name])
        else if (r.kind === "timer") Globals.startTimer(r.seconds)
        else if (r.kind === "calc") Quickshell.execDetached(["wl-copy", r.name])
        Globals.launcherOpen = false
    }

    Connections {
        target: Globals
        function onLauncherOpenChanged() { if (Globals.launcherOpen) root.query = "" }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: Globals.launcherOpen || card.opacity > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Globals.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // véu: clicar fora fecha
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bg, 0.25)
            opacity: Globals.launcherOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
            MouseArea { anchors.fill: parent; onClicked: Globals.launcherOpen = false }
        }

        Rectangle {
            id: card

            width: 640
            height: Math.min(560, header.height + list.contentHeight + 24 + (list.count ? 10 : 0))
            x: (parent.width - width) / 2
            y: parent.height * 0.18
            radius: 22
            color: Theme.alpha(Theme.bg, 0.62)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.16)
            clip: true

            opacity: Globals.launcherOpen ? 1 : 0
            scale: Globals.launcherOpen ? 1 : 0.95
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }
            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent } // não deixa o clique vazar pro véu

            RowLayout {
                id: header
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                height: 36
                spacing: 12

                Text {
                    text: root.query.startsWith("=") ? "󰃬" : root.query.startsWith(">") ? "\uf120" : "\uf002"
                    color: Theme.accent
                    font { family: Theme.iconFont; pixelSize: 20 }
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    text: root.query
                    onTextChanged: { root.query = text; list.currentIndex = 0 }
                    focus: Globals.launcherOpen
                    color: Theme.fg
                    selectionColor: Theme.accentSoft
                    font { family: Theme.font; pixelSize: 20 }
                    verticalAlignment: TextInput.AlignVCenter

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar apps  ·  = calcular  ·  > comando  ·  timer 5m"
                        color: Theme.alpha(Theme.fg, 0.4)
                        font: input.font
                    }

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier
                        if (e.key === Qt.Key_Escape) { Globals.launcherOpen = false }
                        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_J)) { list.incrementCurrentIndex() }
                        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K)) { list.decrementCurrentIndex() }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.activate(root.results[list.currentIndex]) }
                        else return
                        e.accepted = true
                    }

                    Connections {
                        target: Globals
                        function onLauncherOpenChanged() { if (Globals.launcherOpen) input.forceActiveFocus() }
                    }
                }
            }

            Rectangle {
                visible: list.count > 0
                anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: 12; leftMargin: 18; rightMargin: 18 }
                height: 1
                color: Theme.alpha(Theme.fg, 0.1)
            }

            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; topMargin: 22; margins: 10 }
                model: root.results
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Theme.animFast
                highlightResizeDuration: 0
                highlight: Rectangle {
                    radius: 14
                    color: Theme.alpha(Theme.accent, 0.22)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, 0.45)
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 52

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 14

                        IconImage {
                            implicitSize: 32
                            source: Quickshell.iconPath(row.modelData.icon ?? "", true) || Quickshell.iconPath("application-x-executable")
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                elide: Text.ElideRight
                                color: Theme.fg
                                font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.comment ?? ""
                                elide: Text.ElideRight
                                color: Theme.alpha(Theme.fg, 0.55)
                                font { family: Theme.font; pixelSize: 12 }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = row.index
                        onClicked: root.activate(row.modelData)
                    }
                }
            }
        }
    }
}
