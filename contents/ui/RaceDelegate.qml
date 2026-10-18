/*
 * Copyright 2026  Petar Nedyalkov
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import "../code/SportsApi.js" as SportsApi
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// One row for a racing weekend (F1 / NASCAR / IndyCar), used by the Schedule, Recent
// results and Live tabs instead of the two-sided "team vs team" score row.
//
//   collapsed:  date tile | Grand Prix name, circuit, podium (P1 P2 P3) or start time
//   expanded:   session pills (Practice / Qualifying / Race ...) + the full classification
//               of the selected session; a live session shows the running order with
//               places gained / lost since the last refresh.
//
// Everything comes from the row's `racingData` JSON (see normalizeEspnRacingEvent), so
// expanding needs no extra request and the live poll refreshes the order in place.
Rectangle {
    id: root

    property string league: ""
    property string status: ""
    property string minute: ""
    property string statusText: ""
    property string startTime: ""
    property real timestamp: 0
    property string eventName: ""
    property string circuit: ""
    property string location: ""
    // Label of the session the row is about (live session, else the headline one).
    property string sessionLabel: ""
    property string racingTop: "[]"
    property string racingData: ""
    property string espnEventId: ""
    property string espnLeague: ""
    property bool favorite: false
    property bool selected: false
    property bool expanded: false
    // Chosen session tab; owned by the hosting list so it survives the delegate being
    // recreated when the live model is rebuilt.
    property string selectedSession: ""
    property bool showMatchActions: false
    property bool matchNotifyOn: false
    property bool matchPinnedToPanel: false
    property real headerHeight: Kirigami.Units.gridUnit * (root.topList.length > 0 ? 5.0 : 4.2)

    readonly property color liveColor: Kirigami.Theme.negativeTextColor
    readonly property bool isLive: root.status === "Live"
    readonly property bool isUpcoming: root.status === "Upcoming"
    readonly property var topList: root.parseJson(root.racingTop, [])
    readonly property var weekend: root.parseJson(root.racingData, { "sessions": [] })
    readonly property var sessions: Array.isArray(root.weekend.sessions) ? root.weekend.sessions : []
    readonly property var activeSession: root.pickSession()
    readonly property var activeResults: root.activeSession && Array.isArray(root.activeSession.results) ? root.activeSession.results : []
    readonly property bool activeIsLive: root.activeSession !== null && root.activeSession.state === "in"
    // Places gained/lost since the previous poll - only meaningful for a live session.
    readonly property var activeDeltas: root.activeIsLive
        ? SportsApi.racingPositionDeltas(root.espnEventId, root.activeSession.key, root.activeResults) : ({})
    readonly property string visitUrl: {
        if (root.espnEventId.length === 0)
            return "";
        return root.espnLeague.toLowerCase() === "f1"
            ? "https://www.espn.com/f1/race/_/id/" + root.espnEventId
            : "https://www.espn.com/racing/";
    }

    signal clicked()
    signal sessionPicked(string key)
    signal notifyToggled()
    signal panelPinToggled()

    function parseJson(text, fallback) {
        const value = String(text || "");
        if (value.length === 0)
            return fallback;
        try {
            const parsed = JSON.parse(value);
            return parsed === null || parsed === undefined ? fallback : parsed;
        } catch (error) {
            return fallback;
        }
    }

    function withAlpha(color, alpha) {
        try {
            if (!color || color.r === undefined)
                return Qt.rgba(0, 0, 0, 0);
            return Qt.rgba(color.r, color.g, color.b, alpha);
        } catch (error) {
            return Qt.rgba(0, 0, 0, 0);
        }
    }

    // The session whose classification is listed: the user's pick, else the one running
    // now, else the Race (when it has a result), else the latest session with a result.
    function pickSession() {
        const list = root.sessions;
        if (list.length === 0)
            return null;
        const picked = list.find(session => session.key === root.selectedSession);
        if (picked)
            return picked;
        const live = list.find(session => session.state === "in");
        if (live)
            return live;
        const race = list.find(session => (session.key === "Race" || session.label === "Race") && session.results.length > 0);
        if (race)
            return race;
        for (let index = list.length - 1; index >= 0; index -= 1) {
            if (list[index].results.length > 0)
                return list[index];
        }
        return list[list.length - 1];
    }

    // "Max Verstappen" -> "Verstappen", "Carlos Sainz Jr." -> "Sainz": the podium row is narrow.
    function surname(entry) {
        const full = String(entry && (entry.n || entry.s) || "").trim();
        const words = full.split(/\s+/).filter(word => word.length > 0);
        while (words.length > 1 && /^(jr\.?|sr\.?|ii|iii|iv)$/i.test(words[words.length - 1]))
            words.pop();
        return words.length > 0 ? words[words.length - 1] : full;
    }

    function pillText(session) {
        // Series without session types (NASCAR / IndyCar) get keys like "s0": use the label.
        return /^s\d+$/.test(String(session.key || "")) ? String(session.label || "") : String(session.key || session.label || "");
    }

    function stateText(session) {
        if (!session)
            return "";
        if (session.state === "in")
            return i18nc("@info:status racing session is live", "LIVE");
        if (session.state === "post")
            return i18nc("@info:status racing session is finished", "Final");
        return i18nc("@info:status racing session has not started", "Scheduled");
    }

    function medalColor(place) {
        if (place === 1)
            return "#d4af37";
        if (place === 2)
            return "#9aa0a6";
        if (place === 3)
            return "#cd7f32";
        return Kirigami.Theme.textColor;
    }

    function monthText() {
        return root.timestamp > 0 ? Qt.formatDate(new Date(root.timestamp), "MMM").toUpperCase() : "";
    }

    function dayText() {
        return root.timestamp > 0 ? Qt.formatDate(new Date(root.timestamp), "d") : "";
    }

    function circuitLine() {
        const parts = [];
        if (root.circuit.length > 0)
            parts.push(root.circuit);
        if (root.location.length > 0)
            parts.push(root.location);
        return parts.length > 0 ? parts.join(" · ") : root.league;
    }

    // "Next: Qualifying · ..." is redundant when the next session is the one already shown.
    function nextLine() {
        if (!root.isUpcoming || root.statusText.indexOf("Next: ") !== 0)
            return "";
        const label = root.sessionLabel;
        return label.length > 0 && root.statusText.indexOf("Next: " + label) === 0 ? "" : root.statusText;
    }

    implicitHeight: body.implicitHeight
    height: implicitHeight
    color: root.selected || root.expanded ? withAlpha(Kirigami.Theme.highlightColor, 0.18)
        : (root.favorite || hoverHandler.hovered ? withAlpha(Kirigami.Theme.alternateBackgroundColor, 0.5) : "transparent")

    HoverHandler {
        id: hoverHandler
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        visible: root.selected || root.expanded
        color: Kirigami.Theme.highlightColor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: withAlpha(Kirigami.Theme.separatorColor, 0.5)
    }

    Column {
        id: body

        width: root.width
        spacing: 0

        // ---- Header (always visible) ----
        Item {
            id: header

            width: parent.width
            height: root.headerHeight

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clicked()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing * 2

                // Date tile (a red LIVE tile while a session is running).
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.8
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.8
                    radius: Kirigami.Units.smallSpacing * 1.5
                    color: root.isLive ? root.liveColor : root.withAlpha(Kirigami.Theme.textColor, 0.08)
                    border.width: root.isLive ? 0 : 1
                    border.color: root.withAlpha(Kirigami.Theme.textColor, 0.12)

                    Column {
                        anchors.centerIn: parent
                        visible: !root.isLive
                        spacing: 0

                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.monthText()
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.6)
                            font.bold: true
                        }

                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dayText()
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 1.1)
                            font.bold: true
                        }
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        visible: root.isLive
                        text: i18nc("@info:status racing weekend is live", "LIVE")
                        color: Kirigami.Theme.highlightedTextColor
                        font.bold: true
                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.75)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: root.eventName
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    // Live: running session (and lap); otherwise the circuit and place.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        visible: root.isLive

                        Rectangle {
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            radius: 3.5
                            color: root.liveColor
                        }

                        SmallLabel {
                            Layout.fillWidth: true
                            text: root.minute.length > 0 ? root.minute : root.sessionLabel
                            color: root.liveColor
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    SmallLabel {
                        Layout.fillWidth: true
                        visible: !root.isLive
                        text: root.circuitLine()
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    // Upcoming: when the race (or the headline session) starts.
                    SmallLabel {
                        Layout.fillWidth: true
                        visible: root.isUpcoming && text.length > 0
                        text: root.sessionLabel.length > 0 && root.startTime.length > 0
                            ? root.sessionLabel + " · " + root.startTime : root.startTime
                        elide: Text.ElideRight
                    }

                    SmallLabel {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: root.nextLine()
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    // Podium: P1 / P2 / P3 (the running top three while live).
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing / 2
                        visible: root.topList.length > 0
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: 3

                            PodiumItem {
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.minimumWidth: 0
                                place: index + 1
                                entry: index < root.topList.length ? root.topList[index] : null
                            }
                        }
                    }
                }

                // Right edge: per-race actions on top, expand chevron below.
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Kirigami.Units.smallSpacing / 2
                        visible: root.showMatchActions
                        opacity: hoverHandler.hovered || root.matchNotifyOn || root.matchPinnedToPanel ? 1 : 0

                        ActionIcon {
                            active: root.matchNotifyOn
                            inactiveSource: "notifications-disabled-symbolic"
                            activeSource: "notifications-symbolic"
                            tooltip: root.matchNotifyOn
                                ? i18nc("@info:tooltip", "Notifications on for this race - click to mute")
                                : i18nc("@info:tooltip", "Notify me about this race")
                            onTriggered: root.notifyToggled()
                        }

                        ActionIcon {
                            active: root.matchPinnedToPanel
                            inactiveSource: "pin-symbolic"
                            activeSource: "pin"
                            tooltip: root.matchPinnedToPanel
                                ? i18nc("@info:tooltip", "Pinned to the panel - click to unpin")
                                : i18nc("@info:tooltip", "Show this race in the panel")
                            onTriggered: root.panelPinToggled()
                        }
                    }

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: root.expanded ? "go-up-symbolic" : "go-down-symbolic"
                        isMask: true
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        // ---- Expanded: sessions + full classification ----
        Loader {
            id: detailsLoader

            width: parent.width
            active: root.expanded
            visible: active
            height: item ? item.implicitHeight : 0

            sourceComponent: Column {
                id: details

                width: detailsLoader.width
                spacing: Kirigami.Units.smallSpacing
                bottomPadding: Kirigami.Units.smallSpacing * 2

                Flow {
                    x: Kirigami.Units.smallSpacing * 2
                    width: details.width - Kirigami.Units.smallSpacing * 4
                    spacing: Kirigami.Units.smallSpacing
                    visible: root.sessions.length > 1

                    Repeater {
                        model: root.sessions

                        SessionPill {
                            required property var modelData

                            text: root.pillText(modelData)
                            live: modelData.state === "in"
                            dimmed: modelData.results.length === 0
                            active: root.activeSession !== null && modelData.key === root.activeSession.key
                            tooltip: String(modelData.label || "") + (modelData.time ? " · " + modelData.time : "")
                            onClicked: root.sessionPicked(String(modelData.key))
                        }
                    }
                }

                // Selected session: name, start time and state.
                RowLayout {
                    x: Kirigami.Units.smallSpacing * 2
                    width: details.width - Kirigami.Units.smallSpacing * 4
                    visible: root.activeSession !== null
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: root.activeSession ? String(root.activeSession.label || "") : ""
                        font.bold: true
                    }

                    SmallLabel {
                        Layout.fillWidth: true
                        text: root.activeSession ? String(root.activeSession.time || "") : ""
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    SmallLabel {
                        text: root.stateText(root.activeSession)
                        color: root.activeIsLive ? root.liveColor : Kirigami.Theme.disabledTextColor
                        font.bold: root.activeIsLive
                    }
                }

                PlasmaComponents.Label {
                    x: Kirigami.Units.smallSpacing * 2
                    width: details.width - Kirigami.Units.smallSpacing * 4
                    visible: root.activeResults.length === 0
                    text: root.activeSession && root.activeSession.state === "pre"
                        ? i18nc("@info:placeholder", "This session has not started yet.")
                        : i18nc("@info:placeholder", "No classification available for this session.")
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                }

                Column {
                    width: details.width
                    visible: root.activeResults.length > 0

                    Repeater {
                        model: root.activeResults

                        ResultRow {
                            required property var modelData

                            width: details.width
                            entry: modelData
                            delta: root.activeDeltas[String(modelData.n)] || 0
                            showDelta: root.activeIsLive
                        }
                    }
                }

                Item {
                    width: details.width
                    height: visitButton.implicitHeight
                    visible: root.visitUrl.length > 0

                    PlasmaComponents.Button {
                        id: visitButton

                        anchors.centerIn: parent
                        icon.name: "globe"
                        text: i18nc("@action:button open race on ESPN website", "Visit on ESPN")
                        onClicked: Qt.openUrlExternally(root.visitUrl)
                    }
                }
            }
        }
    }

    component SmallLabel: PlasmaComponents.Label {
        font: Kirigami.Theme.smallFont
    }

    // One of the three podium places in the collapsed header.
    component PodiumItem: RowLayout {
        property var entry: null
        property int place: 1

        spacing: Kirigami.Units.smallSpacing / 2
        visible: entry !== null

        PlasmaComponents.Label {
            text: place === 1 ? "🥇" : (place === 2 ? "🥈" : "🥉")
            font: Kirigami.Theme.smallFont
        }

        Item {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small

            TeamBadgeImage {
                anchors.fill: parent
                sourceUrl: entry ? String(entry.f || "") : ""
                fallbackIcon: "flag"
                fallbackEmoji: "🏁"
                fallbackOpacity: 0.45
            }
        }

        SmallLabel {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: entry ? root.surname(entry) : ""
            font.bold: place === 1
            elide: Text.ElideRight
        }
    }

    // One line of the full classification.
    component ResultRow: Item {
        id: resultRow

        property var entry: ({})
        property int delta: 0
        property bool showDelta: false
        readonly property int place: Number(entry.p || 0)

        implicitHeight: Kirigami.Units.gridUnit * 1.7
        height: implicitHeight

        Rectangle {
            anchors.fill: parent
            visible: resultRow.place >= 1 && resultRow.place <= 3
            color: root.withAlpha(root.medalColor(resultRow.place), 0.1)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.withAlpha(Kirigami.Theme.separatorColor, 0.3)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing * 2
            anchors.rightMargin: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                text: resultRow.place > 0 ? String(resultRow.place) : "-"
                horizontalAlignment: Text.AlignRight
                color: root.medalColor(resultRow.place)
                font.bold: true
            }

            SmallLabel {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                visible: resultRow.showDelta
                text: resultRow.delta > 0 ? "▲" + resultRow.delta : (resultRow.delta < 0 ? "▼" + (-resultRow.delta) : "")
                color: resultRow.delta > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }

            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small

                TeamBadgeImage {
                    anchors.fill: parent
                    sourceUrl: String(resultRow.entry.f || "")
                    fallbackIcon: "flag"
                    fallbackEmoji: "🏁"
                    fallbackOpacity: 0.45
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: String(resultRow.entry.n || "")
                font.bold: resultRow.place >= 1 && resultRow.place <= 3
                elide: Text.ElideRight
            }

            SmallLabel {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 9
                visible: text.length > 0
                text: String(resultRow.entry.x || "")
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
        }
    }

    // Session selector chip (FP1 / Qual / Race ...).
    component SessionPill: Rectangle {
        id: pill

        property string text: ""
        property bool active: false
        property bool live: false
        property bool dimmed: false
        property string tooltip: ""

        signal clicked()

        implicitWidth: pillRow.implicitWidth + Kirigami.Units.gridUnit
        implicitHeight: Kirigami.Units.gridUnit * 1.6
        radius: height / 2
        color: active ? Kirigami.Theme.highlightColor
            : (pillMouse.containsMouse ? root.withAlpha(Kirigami.Theme.textColor, 0.1) : "transparent")
        border.width: active ? 0 : 1
        border.color: root.withAlpha(Kirigami.Theme.textColor, 0.2)
        opacity: dimmed && !active ? 0.55 : 1

        Row {
            id: pillRow

            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                visible: pill.live
                color: pill.active ? Kirigami.Theme.highlightedTextColor : root.liveColor
            }

            SmallLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.text
                color: pill.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                font.bold: pill.active
            }
        }

        MouseArea {
            id: pillMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()

            PlasmaComponents.ToolTip.text: pill.tooltip
            PlasmaComponents.ToolTip.visible: containsMouse && pill.tooltip.length > 0
            PlasmaComponents.ToolTip.delay: 600
        }
    }

    // Bell / pin icon, same look as the football rows' actions.
    component ActionIcon: Item {
        id: actionIcon

        property bool active: false
        property string inactiveSource: ""
        property string activeSource: ""
        property string tooltip: ""

        signal triggered()

        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        Kirigami.Icon {
            anchors.fill: parent
            source: actionIcon.active ? actionIcon.activeSource : actionIcon.inactiveSource
            isMask: true
            color: actionIcon.active
                ? Kirigami.Theme.highlightColor
                : (actionMouse.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
        }

        MouseArea {
            id: actionMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: function(mouse) {
                mouse.accepted = true;
                actionIcon.triggered();
            }

            PlasmaComponents.ToolTip.text: actionIcon.tooltip
            PlasmaComponents.ToolTip.visible: containsMouse && actionIcon.tooltip.length > 0
            PlasmaComponents.ToolTip.delay: 600
        }
    }
}
