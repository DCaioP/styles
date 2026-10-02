import QtQuick
import QtQuick.Layouts
import qs

// Card expandido do timer: contagem grande + pausar/cancelar.
Item {
    implicitWidth: 360
    implicitHeight: 104

    RowLayout {
        anchors { fill: parent; leftMargin: 24; rightMargin: 18 }
        spacing: 12

        ColumnLayout {
            spacing: 0
            Text {
                text: Globals.timerRunning ? "Timer" : "Pausado"
                color: Theme.orange
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
            }
            Text {
                text: Globals.fmt(Globals.timerRemaining)
                color: Theme.orange
                font { family: Theme.monoFont; pixelSize: 38; weight: Font.Light }
            }
        }
        Item { Layout.fillWidth: true }
        IconButton {
            size: 46
            icon: Globals.timerRunning ? "󰏤" : "󰐊"
            tint: Theme.orange
            fill: Theme.alpha(Theme.orange, 0.22)
            onClicked: Globals.toggleTimer()
        }
        IconButton {
            size: 46
            icon: "󰅖"
            onClicked: Globals.cancelTimer()
        }
    }

    Rectangle {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 24; bottomMargin: 12 }
        width: (parent.width - 48) * (Globals.timerTotal > 0 ? Globals.timerRemaining / Globals.timerTotal : 0)
        height: 3
        radius: 1.5
        color: Theme.orange
        Behavior on width { NumberAnimation { duration: 900 } }
    }
}
