import QtQuick
import qs

// Barrinhas "tocando" (fake, sem cava): pulam enquanto há som.
Item {
    id: root

    property bool playing: false
    property color color: Theme.accent
    property var levels: [0.3, 0.7, 0.5, 0.9]

    implicitWidth: 4 * 3 + 3 * 2
    implicitHeight: 14

    Timer {
        running: root.playing && root.visible
        interval: 170; repeat: true
        onTriggered: root.levels = root.levels.map(() => 0.15 + Math.random() * 0.85)
    }

    Repeater {
        model: 4
        Rectangle {
            required property int index
            x: index * 5
            width: 3
            radius: 1.5
            height: 3 + (root.playing ? root.levels[index] : 0.1) * (root.height - 3)
            y: (root.height - height) / 2
            color: root.color
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        }
    }
}
