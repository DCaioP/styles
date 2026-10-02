pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Eventos do Google Agenda (via scripts/agenda.py). Atualiza a cada 5 min e
// quando o calendário abre (se o último fetch tiver mais de 1 min).
Singleton {
    id: root

    property var events: []
    property var byDay: ({})          // "YYYY-MM-DD" → [eventos]
    property string error: ""         // "nosources" | "nodeps" | ""
    property var errors: []
    property real lastFetch: 0
    readonly property bool loading: proc.running

    function key(d) {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`
    }

    function refresh(force) {
        if (proc.running) return
        if (!force && Date.now() - lastFetch < 60000) return
        proc.running = true
    }

    function load(text) {
        try {
            const data = JSON.parse(text)
            const map = {}
            for (const ev of data.events ?? [])
                for (const k of ev.days) { if (!map[k]) map[k] = []; map[k].push(ev) }
            events = data.events ?? []
            byDay = map
            error = data.error ?? ""
            errors = data.errors ?? []
            lastFetch = Date.now()
        } catch (e) {
            console.warn("Agenda: saída inválida", e)
        }
    }

    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/agenda.py"]
        stdout: StdioCollector { onStreamFinished: root.load(this.text) }
    }

    Timer {
        running: true; repeat: true; triggeredOnStart: true
        interval: 5 * 60 * 1000
        onTriggered: root.refresh(true)
    }

    function fmtTime(iso) {
        const d = new Date(iso)
        return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`
    }

    function open(ev, day) {
        if (ev?.link) Quickshell.execDetached(["xdg-open", ev.link])
        else {
            const d = day ?? new Date()
            Quickshell.execDetached(["xdg-open", `https://calendar.google.com/calendar/r/day/${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`])
        }
    }
}
