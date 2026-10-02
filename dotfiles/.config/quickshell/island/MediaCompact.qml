import QtQuick
import QtQuick.Layouts
import qs

// Pílula com mídia: capa à esquerda, título, ondas à direita.
RowLayout {
    readonly property var p: Media.player
    spacing: 10

    Art {
        implicitWidth: 22; implicitHeight: 22
        source: parent.p?.trackArtUrl ?? ""
    }
    Text {
        Layout.fillWidth: true
        text: parent.p?.trackTitle || parent.p?.identity || ""
        elide: Text.ElideRight
        color: Theme.islandFg
        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
    }
    Equalizer {
        playing: parent.p?.isPlaying ?? false
    }
}
