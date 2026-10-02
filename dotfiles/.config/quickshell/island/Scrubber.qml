import QtQuick
import qs

// Barra de progresso arrastável. Emite moved(0..1) ao soltar.
Item {
    id: root

    property real value: 0
    signal moved(real v)

    readonly property bool dragging: ma.pressed
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))

    implicitHeight: 14

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: ma.containsMouse || root.dragging ? 7 : 4
        radius: height / 2
        color: Theme.alpha("white", 0.18)
        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
            width: track.width * root.shown
            height: parent.height
            radius: parent.radius
            color: Theme.islandFg
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function at(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: e => root.dragValue = at(e.x)
        onPositionChanged: e => { if (pressed) root.dragValue = at(e.x) }
        onReleased: root.moved(root.dragValue)
    }
}
