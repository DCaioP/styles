import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Pílulas de workspace: a ativa estica, as ocupadas ficam acesas.
// Clique troca; roda do mouse navega.
RowLayout {
    id: root

    required property ShellScreen barScreen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(barScreen)
    readonly property int count: Math.max(5, ...Hyprland.workspaces.values.map(w => w.id).filter(id => id > 0))

    spacing: 6

    Repeater {
        model: root.count

        Rectangle {
            id: pill
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            readonly property bool active: root.monitor?.activeWorkspace?.id === wsId
            readonly property bool occupied: ws !== null && (ws.toplevels?.values.length ?? 1) > 0

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: active ? 28 : (hover.hovered ? 14 : 10)
            implicitHeight: 10
            radius: 5
            color: active ? Theme.accent
                 : occupied ? Theme.alpha(Theme.fg, 0.75)
                 : Theme.alpha(Theme.fg, 0.22)

            Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Hyprland.dispatch(`workspace ${pill.wsId}`) }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => Hyprland.dispatch(e.angleDelta.y > 0 ? "workspace m-1" : "workspace m+1")
    }
}
