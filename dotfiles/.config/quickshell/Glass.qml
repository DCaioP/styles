import QtQuick
import QtQuick.Layouts

// Ilha de vidro: fundo translúcido (o blur vem do compositor via layerrule),
// borda clara fina e um brilho no topo. Os filhos entram numa RowLayout.
Rectangle {
    id: root

    default property alias items: row.data
    property int padding: 14
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: height / 2
    color: Theme.alpha(Theme.bg, 0.45)
    border.width: 1
    border.color: Theme.alpha(Theme.fg, 0.14)

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

    // sheen: gradiente sutil na metade de cima
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: parent.height / 2
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha("white", 0.07) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10
    }
}
