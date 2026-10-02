import QtQuick
import QtQuick.Layouts

// Calendário do mês, desce do bloco do relógio. Roda do mouse ou ‹ › trocam
// de mês; clicar no título volta pra hoje. Dias com evento do Google Agenda
// ganham pontinhos; clicar num dia lista os eventos (clique no evento abre o
// Meet/Zoom ou o dia no Google Agenda).
Rectangle {
    id: root

    property bool open: false
    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()      // 0..11
    property date selected: today
    readonly property var dayEvents: Agenda.byDay[Agenda.key(selected)] ?? []

    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property var weekdays: ["D", "S", "T", "Q", "Q", "S", "S"]
    readonly property var dayNames: ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]

    // 42 células (6 semanas), começando no domingo antes do dia 1
    readonly property var cells: {
        const first = new Date(year, month, 1)
        const start = new Date(year, month, 1 - first.getDay())
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            out.push({ day: d.getDate(), inMonth: d.getMonth() === month, date: d,
                       isToday: d.toDateString() === today.toDateString(),
                       isSelected: d.toDateString() === selected.toDateString(),
                       events: Agenda.byDay[Agenda.key(d)] ?? [],
                       weekend: d.getDay() === 0 || d.getDay() === 6 })
        }
        return out
    }

    function shift(n) {
        const d = new Date(year, month + n, 1)
        year = d.getFullYear(); month = d.getMonth()
    }
    function reset() { today = new Date(); selected = today; year = today.getFullYear(); month = today.getMonth() }

    onOpenChanged: if (open) { reset(); Agenda.refresh(false) }

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 32
    radius: 22
    color: Theme.alpha(Theme.bg, 0.55)
    border.width: 1
    border.color: Theme.alpha(Theme.fg, 0.14)

    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    transformOrigin: Item.TopLeft
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }

    // sheen igual ao Glass
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: 60
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha("white", 0.07) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.monthNames[root.month] + "  " + root.year
                color: Theme.fg
                font { family: Theme.font; pixelSize: 16; weight: Font.Bold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.reset() }
            }
            Repeater {
                model: [{ icon: "\uf053", step: -1 }, { icon: "\uf054", step: 1 }]
                Rectangle {
                    required property var modelData
                    implicitWidth: 28; implicitHeight: 28; radius: 14
                    color: navMa.containsMouse ? Theme.alpha(Theme.fg, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.icon
                        color: Theme.fg
                        font { family: Theme.iconFont; pixelSize: 13 }
                    }
                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shift(parent.modelData.step)
                    }
                }
            }
        }

        GridLayout {
            id: grid
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: root.weekdays
                Text {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.alpha(Theme.fg, index === 0 || index === 6 ? 0.4 : 0.6)
                    font { family: Theme.font; pixelSize: 11; weight: Font.DemiBold }
                }
            }

            Repeater {
                model: root.cells
                Rectangle {
                    id: cell
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 12
                    color: modelData.isToday ? Theme.accent
                         : modelData.isSelected ? Theme.alpha(Theme.fg, 0.16)
                         : cellMa.containsMouse ? Theme.alpha(Theme.fg, 0.10) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 7 }
                        text: cell.modelData.day
                        color: cell.modelData.isToday ? Theme.bg : Theme.fg
                        opacity: !cell.modelData.inMonth ? 0.25 : cell.modelData.weekend && !cell.modelData.isToday ? 0.6 : 1
                        font { family: Theme.font; pixelSize: 13; weight: cell.modelData.isToday ? Font.Bold : Font.Normal }
                    }

                    // até 3 pontinhos, na cor da agenda de cada evento
                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                        spacing: 3
                        opacity: cell.modelData.inMonth ? 1 : 0.35
                        Repeater {
                            model: cell.modelData.events.slice(0, 3)
                            Rectangle {
                                required property var modelData
                                width: 4; height: 4; radius: 2
                                color: cell.modelData.isToday ? Theme.bg : modelData.color
                            }
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected = cell.modelData.date
                        onDoubleClicked: Agenda.open(null, cell.modelData.date)
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.fg, 0.1) }

        // ── Eventos do dia selecionado ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: (root.selected.toDateString() === root.today.toDateString() ? "Hoje, " : "")
                      + root.dayNames[root.selected.getDay()] + ", " + root.selected.getDate()
                      + " de " + root.monthNames[root.selected.getMonth()].toLowerCase()
                color: Theme.alpha(Theme.fg, 0.85)
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
            }
            Text {
                text: "\uf021"
                color: Theme.alpha(Theme.fg, refreshMa.containsMouse ? 0.9 : 0.4)
                font { family: Theme.iconFont; pixelSize: 11 }
                RotationAnimation on rotation { running: Agenda.loading; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                MouseArea { id: refreshMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.refresh(true) }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Agenda.error !== "" || (root.dayEvents.length === 0 && Agenda.lastFetch > 0)
            wrapMode: Text.WordWrap
            text: Agenda.error === "nosources" ? "Agenda não configurada — cole o endereço secreto iCal em ~/.local/share/quickshell/agenda-sources.json"
                : Agenda.error === "nodeps" ? "Falta instalar: python-icalendar python-recurring-ical-events"
                : "Nada marcado"
            color: Theme.alpha(Theme.fg, 0.5)
            font { family: Theme.font; pixelSize: 12 }
        }

        ListView {
            id: evList
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 5 * 44)
            visible: count > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.dayEvents

            delegate: Rectangle {
                id: evRow
                required property var modelData
                width: ListView.view.width
                height: 40
                radius: 10
                color: evMa.containsMouse ? Theme.alpha(Theme.fg, 0.10) : Theme.alpha(Theme.fg, 0.04)
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Rectangle {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 3; height: parent.height - 14; radius: 1.5
                    color: evRow.modelData.color
                }

                ColumnLayout {
                    anchors { left: parent.left; right: linkIcon.left; leftMargin: 20; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: evRow.modelData.title
                        elide: Text.ElideRight
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (evRow.modelData.allDay ? "Dia todo" : Agenda.fmtTime(evRow.modelData.start) + " – " + Agenda.fmtTime(evRow.modelData.end))
                              + (evRow.modelData.location ? "  ·  " + evRow.modelData.location : "")
                        elide: Text.ElideRight
                        color: Theme.alpha(Theme.fg, 0.55)
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }

                Text {
                    id: linkIcon
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: evRow.modelData.link ? "\uf03d" : ""
                    color: Theme.accent
                    font { family: Theme.iconFont; pixelSize: 12 }
                }

                MouseArea {
                    id: evMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Agenda.open(evRow.modelData, root.selected)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Agenda.errors.length > 0
            text: "\uf071  " + Agenda.errors.join(" · ")
            elide: Text.ElideRight
            color: Theme.alpha(Theme.accent, 0.8)
            font { family: Theme.iconFont; pixelSize: 10 }
        }
    }
}
