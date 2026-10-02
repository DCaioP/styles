import QtQuick
import Quickshell.Widgets
import qs

// Dynamic Island. A forma é desenhada por um shader SDF (shaders/island.frag)
// com duas caixas: A (principal) e B (bolha secundária). A geometria anima com
// molas (SpringAnimation) e o conteúdo é recortado pela forma de A/B.
//
// Modos de A: idle → app focado | media | timer | osd (volume, timer concluído)
//             expandido: "media" | "timer" (toque longo ou clique direito)
// Gestos:     toque → abre o app / a busca · toque longo → expande ·
//             swipe lateral → esconde a atividade · tirar o mouse → recolhe
// Split:      mídia + timer ao mesmo tempo → o timer vira uma bolha à direita.
Item {
    id: root

    // expostos pra máscara de input da barra
    readonly property Item hitA: boxA
    readonly property Item hitB: boxB

    property string expanded: ""

    readonly property bool hasMedia: Media.active
    readonly property bool hasTimer: Globals.timerActive
    readonly property string osd: Globals.osdKind

    readonly property string mode:
        expanded !== "" ? "card-" + expanded
        : osd !== "" ? "osd"
        : hasMedia ? "media"
        : hasTimer ? "timer"
        : "idle"
    readonly property bool split: mode === "media" && hasTimer

    // expandido sem a atividade (timer cancelado, player fechou) → recolhe
    onHasMediaChanged: if (!hasMedia && expanded === "media") expanded = ""
    onHasTimerChanged: if (!hasTimer && expanded === "timer") expanded = ""

    // ── Geometria-alvo ─────────────────────────────────────────────────
    readonly property real compactH: 32
    readonly property var target: {
        switch (mode) {
        case "card-media": return { w: 440, h: 176, r: 38 }
        case "card-timer": return { w: 360, h: 104, r: 36 }
        case "osd":        return { w: osd === "volume" ? 330 : 260, h: 38, r: 19 }
        case "media":      return { w: 320, h: compactH, r: compactH / 2 }
        case "timer":      return { w: 140, h: compactH, r: compactH / 2 }
        default:           return { w: Math.max(130, Math.min(380, idle.implicitWidth + 32)), h: compactH, r: compactH / 2 }
        }
    }

    // molas: largura um pouco mais rápida que a altura → "estica e assenta"
    property real aw: target.w
    property real ah: target.h
    property real ar: target.r
    property real splitT: split ? 1 : 0
    property real swipeX: drag.active ? drag.translation.x * 0.35 : 0

    Behavior on aw { SpringAnimation { spring: 4.2; damping: 0.30; epsilon: 0.2 } }
    Behavior on ah { SpringAnimation { spring: 3.4; damping: 0.30; epsilon: 0.2 } }
    Behavior on ar { SpringAnimation { spring: 3.4; damping: 0.32; epsilon: 0.2 } }
    Behavior on splitT { SpringAnimation { spring: 2.6; damping: 0.24; epsilon: 0.005 } }
    Behavior on swipeX { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.2 } }

    readonly property real gap: 8
    readonly property real bw: 74
    readonly property real ax: (width - (aw + Math.max(0, splitT) * (gap + bw))) / 2 + swipeX
    readonly property real ay: 2

    // ── Forma ──────────────────────────────────────────────────────────
    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/island.frag.qsb")

        property size itemSize: Qt.size(width, height)
        property rect rectA: Qt.rect(root.ax, root.ay, root.aw, root.ah)
        property rect rectB: root.splitT > 0.03 ? Qt.rect(boxB.x, boxB.y, boxB.width, boxB.height) : Qt.rect(0, 0, 0, 0)
        property real radiusA: root.ar
        property real radiusB: boxB.height / 2
        property real goo: 18
        property color fillColor: Theme.island
        property color rimColor: "transparent"   // ex.: Theme.alpha("white", 0.08) pra destacar em wallpaper escuro
    }

    // ── A: principal ───────────────────────────────────────────────────
    ClippingRectangle {
        id: boxA
        x: root.ax; y: root.ay
        width: root.aw; height: root.ah
        radius: root.ar
        color: "transparent"

        Layer {
            shown: root.mode === "idle"
            width: boxA.width; height: root.compactH
            IdleContent { id: idle; anchors.centerIn: parent }
        }
        Layer {
            shown: root.mode === "media"
            width: boxA.width; height: root.compactH
            MediaCompact { anchors { fill: parent; leftMargin: 6; rightMargin: 14 } }
        }
        Layer {
            shown: root.mode === "timer"
            width: boxA.width; height: root.compactH
            TimerCompact { anchors.centerIn: parent }
        }
        Layer {
            shown: root.mode === "osd"
            width: boxA.width; height: 38
            OsdContent { kind: root.osd || "volume"; anchors { fill: parent; leftMargin: 18; rightMargin: 18 } }
        }
        Layer {
            shown: root.mode === "card-media"
            width: 440; height: 176
            MediaCard { anchors.fill: parent }
        }
        Layer {
            shown: root.mode === "card-timer"
            width: 360; height: 104
            TimerCard { anchors.fill: parent }
        }

        HoverHandler { id: hoverA }

        TapHandler {
            enabled: root.expanded === ""
            acceptedButtons: Qt.LeftButton
            longPressThreshold: 0.35
            onTapped: root.tap()
            onLongPressed: root.expand()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: root.expanded !== "" ? root.expanded = "" : root.expand()
        }
        DragHandler {
            id: drag
            target: null
            enabled: root.expanded === ""
            yAxis.enabled: false
            onActiveChanged: if (!active && Math.abs(translation.x) > 70) root.dismiss()
        }
    }

    // ── B: bolha secundária (timer quando há mídia) ───────────────────
    ClippingRectangle {
        id: boxB
        width: root.bw
        height: root.compactH
        radius: height / 2
        color: "transparent"
        // splitT=0 → escondida dentro da borda direita de A; 1 → solta ao lado
        x: root.ax + root.aw - width + root.splitT * (root.gap + width)
        y: root.ay + (root.compactH - height) / 2
        visible: root.splitT > 0.03
        enabled: root.split

        TimerCompact {
            anchors.centerIn: parent
            opacity: Math.max(0, Math.min(1, (root.splitT - 0.6) / 0.4))
        }

        TapHandler {
            longPressThreshold: 0.35
            onTapped: root.expanded = "timer"
            onLongPressed: root.expanded = "timer"
        }
    }

    // camada de conteúdo de um modo: aparece por fade+scale quando é a vez dela
    component Layer: Item {
        property bool shown
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.9
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: shown ? 260 : 120; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    // ── Comportamento ──────────────────────────────────────────────────
    function tap() {
        if (mode === "media") Media.focusPlayer()
        else if (mode === "timer") expanded = "timer"
        else if (mode === "idle") Globals.launcherOpen = true
    }

    function expand() {
        if (hasMedia) expanded = "media"
        else if (hasTimer) expanded = "timer"
    }

    function dismiss() {
        if (mode === "media") Media.dismiss()
        else if (mode === "timer") Globals.timerHidden = true
    }

    Connections {
        target: Globals
        function onIslandRequest(what) {
            if (what === "media" && root.hasMedia || what === "timer" && root.hasTimer || what === "") root.expanded = what
        }
    }

    // tirou o mouse do card → recolhe. Aberto por atalho (sem o mouse ter
    // entrado) espera mais antes de recolher.
    property bool hoveredOnce: false
    onExpandedChanged: hoveredOnce = hoverA.hovered
    Connections { target: hoverA; function onHoveredChanged() { if (hoverA.hovered) root.hoveredOnce = true } }
    Timer {
        running: root.expanded !== "" && !hoverA.hovered
        interval: root.hoveredOnce ? 800 : 4000
        onTriggered: root.expanded = ""
    }
}
