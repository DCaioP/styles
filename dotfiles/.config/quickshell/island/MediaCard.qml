import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs

// Card expandido de mídia: capa desfocada ao fundo, scrubber e controles.
Item {
    id: root

    readonly property var p: Media.player
    readonly property real length: p?.length ?? 0
    readonly property real position: p?.position ?? 0

    implicitWidth: 440
    implicitHeight: 176

    Image {
        id: bgArt
        anchors.fill: parent
        source: root.p?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        sourceSize { width: 128; height: 128 }
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: bgArt
        visible: bgArt.status === Image.Ready
        blurEnabled: true; blur: 1.0; blurMax: 64
        saturation: 0.2
        opacity: 0.38
    }

    ColumnLayout {
        anchors { fill: parent; margins: 20; topMargin: 22 }
        spacing: 12

        RowLayout {
            spacing: 14
            Art {
                implicitWidth: 58; implicitHeight: 58
                radius: 14
                source: root.p?.trackArtUrl ?? ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.p?.trackTitle || "Sem título"
                    elide: Text.ElideRight
                    color: Theme.islandFg
                    font { family: Theme.font; pixelSize: 16; weight: Font.Bold }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.p?.trackArtist || root.p?.identity || ""
                    elide: Text.ElideRight
                    color: Theme.islandMuted
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
            Equalizer {
                Layout.alignment: Qt.AlignTop
                implicitHeight: 18
                playing: root.p?.isPlaying ?? false
            }
        }

        RowLayout {
            spacing: 10
            visible: root.length > 0
            Text {
                text: Globals.fmt(scrub.dragging ? scrub.dragValue * root.length : root.position)
                color: Theme.islandMuted
                font { family: Theme.monoFont; pixelSize: 11 }
            }
            Scrubber {
                id: scrub
                Layout.fillWidth: true
                value: root.length > 0 ? root.position / root.length : 0
                onMoved: v => { if (root.p?.canSeek) root.p.position = v * root.length }
            }
            Text {
                text: "-" + Globals.fmt(root.length - (scrub.dragging ? scrub.dragValue * root.length : root.position))
                color: Theme.islandMuted
                font { family: Theme.monoFont; pixelSize: 11 }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 22
            IconButton { icon: "󰒮"; fill: "transparent"; size: 36; onClicked: root.p?.previous() }
            IconButton { icon: root.p?.isPlaying ? "󰏤" : "󰐊"; size: 44; onClicked: root.p?.togglePlaying() }
            IconButton { icon: "󰒭"; fill: "transparent"; size: 36; onClicked: root.p?.next() }
        }
    }
}
