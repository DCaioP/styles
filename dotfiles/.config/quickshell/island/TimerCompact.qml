import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    spacing: 6
    Text {
        text: Globals.timerRunning ? "󰔛" : "󰏤"
        color: Theme.orange
        font { family: Theme.iconFont; pixelSize: 13 }
    }
    Text {
        text: Globals.fmt(Globals.timerRemaining)
        color: Theme.orange
        font { family: Theme.monoFont; pixelSize: 12; weight: Font.DemiBold }
    }
}
