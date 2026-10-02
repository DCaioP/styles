import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// Ilha em repouso: app focado. Sem janela → atalho pra busca.
RowLayout {
    id: root

    readonly property var tl: ToplevelManager.activeToplevel
    readonly property string title: tl?.title ?? ""
    readonly property string iconSrc: tl ? (Quickshell.iconPath(tl.appId, true) || Quickshell.iconPath(tl.appId.toLowerCase(), true)) : ""

    spacing: 8

    IconImage {
        visible: root.iconSrc !== ""
        implicitSize: 16
        source: root.iconSrc
    }
    Text {
        visible: root.iconSrc === ""
        text: root.title === "" ? "\uf002" : "󰣆"
        color: Theme.islandMuted
        font { family: Theme.iconFont; pixelSize: 13 }
    }
    Text {
        Layout.maximumWidth: 300
        text: root.title === "" ? "Buscar" : root.title
        elide: Text.ElideRight
        color: root.title === "" ? Theme.islandMuted : Theme.islandFg
        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
    }
}
