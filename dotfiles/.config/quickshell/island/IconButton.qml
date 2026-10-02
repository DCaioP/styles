import QtQuick
import qs

Rectangle {
    id: root

    property string icon
    property int size: 34
    property color tint: Theme.islandFg
    property color fill: Theme.alpha("white", 0.10)
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: ma.pressed ? Qt.lighter(fill, 1.6) : ma.containsMouse ? Qt.lighter(fill, 1.3) : fill
    scale: ma.pressed ? 0.88 : 1

    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 110 } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.tint
        font { family: Theme.iconFont; pixelSize: Math.round(root.size * 0.48) }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
