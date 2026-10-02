import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// Busca/launcher estilo Spotlight. Abre centrado no cursor (preso às bordas
// do monitor sob ele); se o hyprctl falhar, cai no centro do monitor focado.
// Fechado: só a pílula de busca + botões de modo. Ao digitar, a pílula
// estica, os botões somem e os resultados descem num cartão por baixo.
//   texto      → apps e ações (fuzzy + mais usados primeiro)
//   = 2*(3+4)  → calculadora
//   > comando  → roda no shell
//   timer 5m   → timer na Dynamic Island
// Modos (botões ou Ctrl+1..4): apps, arquivos, ações, área de transferência.
// Antes de digitar, ←/→ (ou Tab) andam entre os botões e Enter entra no modo.
// ↑/↓ ou Ctrl+J/K navegam, Enter executa, Backspace vazio sai do modo,
// Esc limpa → sai do modo → fecha.
Scope {
    id: root

    property string query: ""
    property string mode: ""            // "" | apps | files | actions | clipboard
    property var usage: ({})
    property var fileResults: []
    property var clipResults: []
    property int btnIndex: -1           // botão selecionado pelo teclado (-1 = campo de busca)

    readonly property bool expanded: query !== "" || mode !== ""

    readonly property var modes: [
        { id: "apps",      icon: "", label: "Apps",       hint: "Buscar apps" },
        { id: "files",     icon: "", label: "Arquivos",   hint: "Buscar arquivos na home" },
        { id: "actions",   icon: "", label: "Ações",      hint: "Ações do sistema" },
        { id: "clipboard", icon: "", label: "Clipboard",  hint: "Histórico da área de transferência" }
    ]
    readonly property var currentMode: modes.find(m => m.id === mode) ?? null

    function toggle() {
        if (Globals.launcherOpen) Globals.launcherOpen = false
        else cursorProc.running = true   // abre quando a posição do cursor chegar
    }

    // posição global (lógica) do cursor no momento de abrir
    property point cursor: Qt.point(-1, -1)
    readonly property var cursorScreen: Quickshell.screens.find(s =>
        cursor.x >= s.x && cursor.x < s.x + s.width && cursor.y >= s.y && cursor.y < s.y + s.height) ?? null

    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const c = JSON.parse(this.text); root.cursor = Qt.point(c.x, c.y) }
                catch (e) { root.cursor = Qt.point(-1, -1) }
                Globals.launcherOpen = true
            }
        }
    }

    function setMode(m) {
        btnIndex = -1
        mode = mode === m ? "" : m
        query = ""
        if (mode === "clipboard") { clipProc.running = false; clipProc.running = true }
        if (mode === "files") fileDebounce.restart()
    }

    // atalho global sem spawnar processo: bind = SUPER CTRL, RETURN, global, quickshell:launcher
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

    // ── Fontes de resultado ──────────────────────────────────────────────

    readonly property var actions: [
        { kind: "prefix", prefix: "= ",     name: "Calculadora",      comment: "= 2*(3+4)",   glyph: "\uf1ec" },
        { kind: "prefix", prefix: "> ",     name: "Rodar comando",    comment: "> comando",   glyph: "\uf120" },
        { kind: "prefix", prefix: "timer ", name: "Timer",            comment: "timer 5m",    glyph: "\uf254" },
        { kind: "exec", exec: ["waypaper"],              name: "Trocar wallpaper", comment: "waypaper",     glyph: "\uf03e" },
        { kind: "exec", exec: ["emoji-picker"],          name: "Seletor de emoji", comment: "emoji-picker", glyph: "\uf118" },
        { kind: "exec", exec: ["hyprlock"],              name: "Bloquear tela",    comment: "hyprlock",     glyph: "\uf023" },
        { kind: "exec", exec: ["systemctl", "suspend"],  name: "Suspender",        comment: "systemctl suspend",  glyph: "\uf186" },
        { kind: "exec", exec: ["systemctl", "reboot"],   name: "Reiniciar",        comment: "systemctl reboot",   glyph: "\uf021" },
        { kind: "exec", exec: ["systemctl", "poweroff"], name: "Desligar",         comment: "systemctl poweroff", glyph: "\uf011" }
    ]

    function appResults(needle) {
        return DesktopEntries.applications.values
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
    }

    function actionResults(needle) {
        return actions
            .map(a => Object.assign({ score: needle === "" ? 1 : fuzzy(needle, a.name) * 0.8 }, a))
            .filter(a => a.score > 0)
    }

    readonly property var results: {
        const q = query.trim()
        const needle = q.toLowerCase()
        const byScore = (a, b) => b.score - a.score || a.name.localeCompare(b.name)

        if (mode === "apps") return appResults(needle).sort(byScore).slice(0, 80)
        if (mode === "actions") return needle === "" ? actions : actionResults(needle).sort(byScore)
        if (mode === "files") return fileResults
        if (mode === "clipboard")
            return needle === "" ? clipResults : clipResults.filter(c => c.name.toLowerCase().includes(needle))

        if (q === "") return []

        if (q.startsWith("=")) {
            const expr = q.slice(1).trim()
            if (/^[\d\s+\-*/().,%^]+$/.test(expr) && expr !== "") {
                try {
                    const v = Function(`"use strict"; return (${expr.replace(/\^/g, "**").replace(/,/g, ".")})`)()
                    if (isFinite(v)) return [{ kind: "calc", name: String(+v.toFixed(10)), comment: expr + "  ·  Enter copia", glyph: "\uf1ec" }]
                } catch (e) {}
            }
            return []
        }

        const t = q.match(/^timer\s+(\d+)\s*(s|m|h)?$/i)
        if (t) {
            const sec = +t[1] * ({ s: 1, m: 60, h: 3600 }[(t[2] ?? "m").toLowerCase()])
            return [{ kind: "timer", seconds: sec, name: "Timer de " + Globals.fmt(sec), comment: "Inicia na Dynamic Island", glyph: "\uf254" }]
        }

        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim()
            return cmd ? [{ kind: "cmd", name: cmd, comment: "Rodar no shell", glyph: "\uf120" }] : []
        }

        return appResults(needle).concat(actionResults(needle)).sort(byScore).slice(0, 50)
    }

    // arquivos: find na home (sem ocultos/node_modules), com debounce
    readonly property string home: Quickshell.env("HOME")
    readonly property var xdgDirs: ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos", "programing"]

    function tildify(p) { return p.startsWith(home) ? "~" + p.slice(home.length) : p }

    Timer {
        id: fileDebounce
        interval: 160
        onTriggered: {
            const q = root.query.trim()
            if (q === "") {
                root.fileResults = [{ kind: "file", path: root.home, name: "Home", comment: "~", glyph: "\uf015" }]
                    .concat(root.xdgDirs.map(d => ({ kind: "file", path: root.home + "/" + d, name: d, comment: "~/" + d, glyph: "\uf07b" })))
                return
            }
            fileProc.running = false
            fileProc.command = ["sh", "-c",
                'find "$HOME" -maxdepth 6 \\( -name ".*" -o -name node_modules -o -name __pycache__ \\) -prune -o -iname "*$1*" -printf "%y\\t%p\\n" 2>/dev/null | head -60',
                "sh", q]
            fileProc.running = true
        }
    }

    Process {
        id: fileProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.fileResults = this.text.split("\n").filter(l => l).map(l => {
                    const [type, path] = [l.slice(0, 1), l.slice(2)]
                    const parts = path.split("/")
                    return { kind: "file", path: path, name: parts[parts.length - 1],
                             comment: root.tildify(parts.slice(0, -1).join("/")),
                             glyph: type === "d" ? "\uf07b" : "\uf15b" }
                })
            }
        }
    }

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipResults = this.text.split("\n").filter(l => l).slice(0, 150).map(l => {
                    const tab = l.indexOf("\t")
                    const text = l.slice(tab + 1).trim()
                    const binary = text.startsWith("[[ binary")
                    return { kind: "clip", raw: l, name: text, comment: binary ? "Imagem" : "",
                             glyph: binary ? "\uf03e" : "\uf0ea" }
                })
            }
        }
    }

    onQueryChanged: if (mode === "files") fileDebounce.restart()

    function activate(r) {
        if (!r) return
        if (r.kind === "prefix") { mode = ""; query = r.prefix; return }   // fica aberto pro usuário completar
        if (r.kind === "app") { bump(r.entry.id); r.entry.execute() }
        else if (r.kind === "exec") Quickshell.execDetached(r.exec)
        else if (r.kind === "cmd") Quickshell.execDetached(["sh", "-c", r.name])
        else if (r.kind === "timer") Globals.startTimer(r.seconds)
        else if (r.kind === "calc") Quickshell.execDetached(["wl-copy", r.name])
        else if (r.kind === "file") Quickshell.execDetached(["xdg-open", r.path])
        else if (r.kind === "clip") Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", r.raw])
        Globals.launcherOpen = false
    }

    Connections {
        target: Globals
        function onLauncherOpenChanged() { if (Globals.launcherOpen) { root.query = ""; root.mode = ""; root.btnIndex = -1 } }
    }

    // ── UI ───────────────────────────────────────────────────────────────

    // vidro: translúcido (blur vem do compositor via layerrule), borda fina e sheen no topo
    component GlassShape: Rectangle {
        color: Theme.alpha(Theme.bg, 0.55)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.16)

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
            height: Math.min(parent.height / 2, 40)
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha("white", 0.08) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    PanelWindow {
        id: win

        screen: root.cursorScreen ?? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: Globals.launcherOpen || stage.opacity > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Globals.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // clicar fora fecha (sem escurecer a tela, como no Spotlight)
        MouseArea { anchors.fill: parent; onClicked: Globals.launcherOpen = false }

        Item {
            id: stage

            readonly property int barH: 54
            readonly property int gap: 10

            width: 720
            height: barH + gap + results.height
            readonly property int edge: 16
            // centrado no cursor; o y deixa espaço pros resultados (até 460) caberem embaixo
            x: root.cursorScreen
                ? Math.max(edge, Math.min(root.cursor.x - win.screen.x - width / 2, parent.width - width - edge))
                : (parent.width - width) / 2
            y: root.cursorScreen
                ? Math.max(edge, Math.min(root.cursor.y - win.screen.y - barH / 2, parent.height - barH - gap - 460 - edge))
                : parent.height * 0.2

            opacity: Globals.launcherOpen ? 1 : 0
            scale: Globals.launcherOpen ? 1 : 0.94
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }

            // ── pílula de busca ──
            GlassShape {
                id: bar

                height: stage.barH
                width: root.expanded ? stage.width : stage.width - buttons.width - stage.gap
                radius: height / 2
                Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

                MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                    spacing: 12

                    Text {
                        text: root.query.startsWith("=") ? "󰃬" : root.query.startsWith(">") ? "" : ""
                        color: Theme.alpha(Theme.fg, 0.7)
                        font { family: Theme.iconFont; pixelSize: 19 }
                    }

                    // chip do modo ativo
                    Rectangle {
                        visible: root.currentMode !== null
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: chip.implicitWidth + 22
                        radius: height / 2
                        color: Theme.alpha(Theme.accent, 0.28)
                        border.width: 1
                        border.color: Theme.alpha(Theme.accent, 0.5)

                        Row {
                            id: chip
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.currentMode?.icon ?? ""
                                color: Theme.fg
                                font { family: Theme.iconFont; pixelSize: 13 }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.currentMode?.label ?? ""
                                color: Theme.fg
                                font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
                            }
                        }
                    }

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        text: root.query
                        onTextChanged: { root.query = text; root.btnIndex = -1; list.currentIndex = 0 }
                        cursorVisible: activeFocus && root.btnIndex < 0
                        focus: Globals.launcherOpen
                        color: Theme.fg
                        selectionColor: Theme.accentSoft
                        font { family: Theme.font; pixelSize: 21 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Text {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.currentMode?.hint ?? "Buscar"
                            color: Theme.alpha(Theme.fg, 0.45)
                            font: input.font
                        }

                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier
                            const n = e.key - Qt.Key_1
                            const last = root.modes.length - 1
                            // barra recolhida: setas/Tab andam entre os botões
                            if (!root.expanded && (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)) { root.btnIndex = Math.min(root.btnIndex + 1, last) }
                            else if (!root.expanded && (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab)) { root.btnIndex = Math.max(root.btnIndex - 1, -1) }
                            else if (root.btnIndex >= 0 && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { root.setMode(root.modes[root.btnIndex].id) }
                            else if (root.btnIndex >= 0 && e.key === Qt.Key_Escape) { root.btnIndex = -1 }
                            else if (e.key === Qt.Key_Escape) {
                                if (root.query !== "") root.query = ""
                                else if (root.mode !== "") root.mode = ""
                                else Globals.launcherOpen = false
                            }
                            else if (e.key === Qt.Key_Backspace && input.text === "" && root.mode !== "") { root.mode = "" }
                            else if (ctrl && n >= 0 && n < root.modes.length) { root.setMode(root.modes[n].id) }
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
            }

            // ── botões de modo (somem ao expandir) ──
            Row {
                id: buttons
                anchors { right: parent.right; top: parent.top }
                spacing: stage.gap
                opacity: root.expanded ? 0 : 1
                scale: root.expanded ? 0.7 : 1
                transformOrigin: Item.Left
                enabled: !root.expanded
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

                Repeater {
                    model: root.modes

                    GlassShape {
                        id: btn
                        required property var modelData
                        required property int index
                        width: stage.barH; height: stage.barH
                        radius: width / 2
                        readonly property bool selected: btnArea.containsMouse || root.btnIndex === index
                        scale: btnArea.pressed ? 0.9 : selected ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.alpha(Theme.accent, btn.selected ? 0.22 : 0)
                            border.width: root.btnIndex === btn.index ? 1 : 0
                            border.color: Theme.alpha(Theme.accent, 0.6)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: btn.modelData.icon
                            color: Theme.fg
                            font { family: Theme.iconFont; pixelSize: 19 }
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { root.setMode(btn.modelData.id); input.forceActiveFocus() }
                        }
                    }
                }
            }

            // ── resultados (descem ao expandir) ──
            GlassShape {
                id: results

                y: stage.barH + stage.gap
                width: stage.width
                height: !root.expanded ? 0 : list.count ? Math.min(460, list.contentHeight + 20) : 54
                radius: 26
                clip: true
                opacity: root.expanded ? 1 : 0
                Behavior on height { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                MouseArea { anchors.fill: parent } // não deixa o clique vazar e fechar

                Text {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    text: root.mode === "files" && fileProc.running ? "Buscando…" : "Nada encontrado"
                    color: Theme.alpha(Theme.fg, 0.5)
                    font { family: Theme.font; pixelSize: 15 }
                }

                ListView {
                    id: list
                    anchors { fill: parent; margins: 10 }
                    model: root.results
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: Theme.animFast
                    highlightResizeDuration: 0
                    highlight: Rectangle {
                        radius: 16
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

                            // ícone do tema (apps); sem ícone ou com falha → glifo num quadradinho
                            Item {
                                implicitWidth: 32; implicitHeight: 32

                                IconImage {
                                    id: themeIcon
                                    anchors.fill: parent
                                    visible: status === Image.Ready
                                    source: row.modelData.glyph ? "" : Quickshell.iconPath(row.modelData.icon ?? "", true)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: !themeIcon.visible
                                    radius: 9
                                    color: Theme.alpha(Theme.accent, 0.22)
                                    border.width: 1
                                    border.color: Theme.alpha(Theme.accent, 0.45)

                                    Text {
                                        anchors.centerIn: parent
                                        text: row.modelData.glyph ?? "\uf2d0"   // padrão: janela
                                        color: Theme.fg
                                        font { family: Theme.iconFont; pixelSize: 15 }
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    color: Theme.fg
                                    font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.modelData.comment ?? ""
                                    elide: Text.ElideMiddle
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
}
