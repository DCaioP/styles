pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Player MPRIS "da vez": o que está tocando; senão o último com faixa.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player:
        players.find(p => p.isPlaying) ?? players.find(p => p.trackTitle) ?? null

    // swipe na ilha esconde a mídia até a faixa mudar
    property string dismissedTrack: ""
    readonly property string trackKey: player ? `${player.identity}|${player.trackTitle}` : ""
    // pausado há mais de 10 min (ou aba que nunca tocou) não ocupa a ilha
    property var lastPlaying: ({})
    property real now: Date.now()
    readonly property bool recent: player !== null && (player.isPlaying || now - (lastPlaying[player.identity] ?? 0) < 10 * 60 * 1000)
    readonly property bool active: recent && trackKey !== dismissedTrack

    Variants {
        model: Mpris.players.values
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() { root.stamp(modelData) }
            Component.onCompleted: root.stamp(modelData)
        }
    }
    function stamp(p) {
        if (!p.isPlaying) return
        const m = Object.assign({}, lastPlaying); m[p.identity] = Date.now(); lastPlaying = m
    }
    Timer { running: true; repeat: true; interval: 30000; onTriggered: root.now = Date.now() }
    function dismiss() { dismissedTrack = trackKey }

    // MprisPlayer.position não se atualiza sozinho: precisa do sinal manual
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000; repeat: true
        onTriggered: root.player.positionChanged()
    }

    function focusPlayer() {
        if (!player) return
        if (player.canRaise) player.raise()
        else if (player.desktopEntry) Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", `class:(?i)${player.desktopEntry}`])
    }
}
