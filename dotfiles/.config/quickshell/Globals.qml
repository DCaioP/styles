pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Estado compartilhado entre barra, ilha e launcher (todas as telas).
Singleton {
    id: root

    property bool launcherOpen: false

    // pedido de expandir/recolher a ilha (IPC, atalhos) — ouvido por cada Island
    signal islandRequest(string what)
    signal calendarToggle()     // só a barra do monitor focado reage

    // ── Timer ─────────────────────────────────────────────────────────
    property int timerTotal: 0
    property int timerRemaining: 0
    property bool timerRunning: false
    property bool timerHidden: false
    readonly property bool timerActive: timerTotal > 0 && !timerHidden

    function startTimer(seconds) {
        timerTotal = seconds; timerRemaining = seconds
        timerRunning = true; timerHidden = false
    }
    function toggleTimer() { if (timerTotal > 0) timerRunning = !timerRunning }
    function cancelTimer() { timerRunning = false; timerTotal = 0; timerRemaining = 0 }

    Timer {
        interval: 1000; repeat: true
        running: root.timerRunning
        onTriggered: {
            root.timerRemaining -= 1
            if (root.timerRemaining <= 0) {
                root.cancelTimer()
                root.flash("timerDone", 5000)
                Quickshell.execDetached(["notify-send", "-a", "Timer", "Timer concluído", "-i", "alarm-symbolic"])
            }
        }
    }

    // ── OSD transitório (volume, timer concluído...) ───────────────────
    property string osdKind: ""
    function flash(kind, ms) { osdKind = kind; osdTimer.interval = ms ?? 1600; osdTimer.restart() }
    Timer { id: osdTimer; onTriggered: root.osdKind = "" }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    property bool _armed: false     // ignora as mudanças de volume do boot
    Timer { running: true; interval: 2500; onTriggered: root._armed = true }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { if (root._armed) root.flash("volume") }
        function onMutedChanged() { if (root._armed) root.flash("volume") }
    }

    // qs ipc call calendar toggle
    IpcHandler {
        target: "calendar"
        function toggle(): void { root.calendarToggle() }
    }

    // qs ipc call island timer 300   |   qs ipc call island cancel
    IpcHandler {
        target: "island"
        function timer(seconds: int): void { root.startTimer(seconds) }
        function toggle(): void { root.toggleTimer() }
        function cancel(): void { root.cancelTimer() }
        // what: "media" | "timer" | "" (recolhe)
        function expand(what: string): void { root.islandRequest(what) }
    }

    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec))
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60
        const mm = String(m).padStart(2, "0"), ss = String(s).padStart(2, "0")
        return h > 0 ? `${h}:${mm}:${ss}` : `${m}:${ss}`
    }
}
