import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Janela própria da ilha, SEM blur do compositor. Na camada da barra o blur
// vazava pela borda antialiasada (fundo borrado com o branco das janelas
// abaixo) e desenhava um contorno claro em volta do preto.
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    anchors.top: true               // sem left/right → centralizada
    margins.top: 6
    implicitWidth: 900
    implicitHeight: 400
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-island"

    mask: Region {
        Region { item: island.hitA }
        Region { item: island.hitB }
    }

    Island {
        id: island
        anchors.fill: parent
    }
}
