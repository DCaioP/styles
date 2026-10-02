import QtQuick
import Quickshell.Widgets
import qs

// Capa do álbum arredondada, com ícone de nota quando não há capa.
ClippingRectangle {
    id: root

    property string source
    radius: 6
    color: Theme.alpha("white", 0.12)

    Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: "󰎆"
        color: Theme.islandMuted
        font { family: Theme.iconFont; pixelSize: root.height * 0.5 }
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize { width: 256; height: 256 }
    }
}
