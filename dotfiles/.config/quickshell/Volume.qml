import QtQuick
import Quickshell.Services.Pipewire

// Volume do sink padrão: roda ajusta, clique muta.
Text {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker { objects: [root.sink] }

    text: (muted ? "󰝟" : volume > 0.6 ? "󰕾" : volume > 0.25 ? "󰖀" : "󰕿") + "  " + Math.round(volume * 100) + "%"
    color: muted ? Theme.muted : Theme.fg
    font { family: Theme.iconFont; pixelSize: 13 }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.muted
        onWheel: e => {
            if (!root.sink?.audio) return
            const step = e.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0, Math.min(1.5, root.volume + step))
        }
    }
}
