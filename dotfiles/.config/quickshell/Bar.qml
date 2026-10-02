import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Barra flutuante: [relógio · workspaces]   ( ilha: island/IslandWindow )   [tray · volume]
//
// A janela é mais alta que a barra pra a ilha poder expandir pra baixo; a
// zona exclusiva continua só a altura da barra e a máscara de input deixa
// passar cliques em tudo que não é ilha/vidro.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    margins { top: 6; left: 10; right: 10 }
    implicitHeight: 400
    exclusiveZone: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    mask: Region {
        Region { item: left }
        Region { item: right }
        Region { item: calendar.visible ? calendar : null }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Glass {
        id: left
        anchors { left: parent.left; top: parent.top }
        spacing: 14

        Text {
            text: Qt.formatDateTime(clock.date, "ddd dd MMM   HH:mm")
            color: calendar.open ? Theme.accent : Theme.fg
            font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            HoverHandler { id: clockHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: calendar.open = !calendar.open }
        }
        Workspaces { barScreen: bar.modelData }
    }

    Calendar {
        id: calendar
        anchors { left: parent.left; top: left.bottom; topMargin: 8 }

        HoverHandler { id: calHover }
    }

    Connections {
        target: Globals
        function onCalendarToggle() {
            if (Hyprland.focusedMonitor?.name === bar.modelData.name) calendar.open = !calendar.open
        }
    }

    // saiu do relógio e do calendário → fecha (folga pra atravessar o vão)
    Timer {
        running: calendar.open && !calHover.hovered && !clockHover.hovered
        interval: 700
        onTriggered: calendar.open = false
    }

    Glass {
        id: right
        anchors { right: parent.right; top: parent.top }

        SysTray { barWindow: bar }
        Volume {}
    }
}
