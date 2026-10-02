import QtQuick
import QtQuick.Layouts
import qs

// Feedback momentâneo: volume ou timer concluído.
RowLayout {
    id: root

    property string kind
    readonly property real vol: Globals.sink?.audio?.volume ?? 0
    readonly property bool muted: Globals.sink?.audio?.muted ?? false

    spacing: 12

    Text {
        text: root.kind === "timerDone" ? "󰀠"
            : root.muted ? "󰝟" : root.vol > 0.6 ? "󰕾" : root.vol > 0.25 ? "󰖀" : "󰕿"
        color: root.kind === "timerDone" ? Theme.orange : Theme.islandFg
        font { family: Theme.iconFont; pixelSize: 17 }

        SequentialAnimation on scale {
            running: root.kind === "timerDone"
            loops: Animation.Infinite
            NumberAnimation { to: 1.25; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 300; easing.type: Easing.InQuad }
        }
    }

    // volume
    Rectangle {
        visible: root.kind === "volume"
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.alpha("white", 0.18)
        Rectangle {
            width: parent.width * Math.min(1, root.muted ? 0 : root.vol)
            height: parent.height
            radius: parent.radius
            color: Theme.islandFg
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    Text {
        visible: root.kind === "volume"
        text: Math.round(root.vol * 100) + "%"
        color: Theme.islandMuted
        font { family: Theme.monoFont; pixelSize: 12 }
    }

    Text {
        visible: root.kind === "timerDone"
        Layout.fillWidth: true
        text: "Timer concluído"
        color: Theme.islandFg
        font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
    }
}
