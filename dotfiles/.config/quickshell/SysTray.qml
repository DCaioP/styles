import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

RowLayout {
    id: root

    required property var barWindow
    spacing: 8
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: item
            required property SystemTrayItem modelData

            implicitWidth: 18
            implicitHeight: 18
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            IconImage {
                anchors.fill: parent
                source: item.modelData.icon
                scale: item.containsMouse ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            }
            hoverEnabled: true

            onClicked: m => {
                if (m.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate()
                } else if (modelData.hasMenu) {
                    const p = item.mapToItem(null, 0, item.height + 8)
                    modelData.display(root.barWindow, p.x, p.y)
                }
            }
        }
    }
}
