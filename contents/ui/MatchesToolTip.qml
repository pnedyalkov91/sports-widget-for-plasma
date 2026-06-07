/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../code/SportsApi.js" as SportsApi
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var liveModel
    property var scheduleModel
    readonly property int maximumRowsPerSection: 8

    function modelCount(model) {
        try {
            const count = Number(model && model.count);
            return Number.isFinite(count) ? count : 0;
        } catch (error) {
            return 0;
        }
    }

    function normalizedTimestamp(match) {
        let timestamp = Number(match && match.timestamp || 0);
        if (!Number.isFinite(timestamp) || timestamp <= 0)
            return 0;
        if (timestamp < 100000000000)
            timestamp *= 1000;
        return timestamp;
    }

    function copyMatch(match) {
        const copy = {};
        if (!match)
            return copy;
        for (let key in match)
            copy[key] = match[key];
        return copy;
    }

    function liveRows() {
        const rows = [];
        const count = Math.min(root.modelCount(root.liveModel), root.maximumRowsPerSection);
        for (let index = 0; index < count; index += 1)
            rows.push(root.copyMatch(root.liveModel.get(index)));
        return rows;
    }

    function upcomingRows() {
        const candidates = [];
        const now = Date.now();
        const today = new Date();
        const endOfTomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 2).getTime();
        const count = root.modelCount(root.scheduleModel);
        for (let index = 0; index < count; index += 1) {
            const match = root.copyMatch(root.scheduleModel.get(index));
            const timestamp = root.normalizedTimestamp(match);
            if (timestamp <= 0 || timestamp < now)
                continue;
            match.normalizedTimestamp = timestamp;
            candidates.push(match);
        }

        candidates.sort((left, right) => left.normalizedTimestamp - right.normalizedTimestamp);
        let rows = candidates.filter(match => match.normalizedTimestamp < endOfTomorrow);
        if (rows.length === 0 && candidates.length > 0) {
            const first = new Date(candidates[0].normalizedTimestamp);
            const nextDayEnd = new Date(first.getFullYear(), first.getMonth(), first.getDate() + 1).getTime();
            rows = candidates.filter(match => match.normalizedTimestamp < nextDayEnd);
        }
        return rows.slice(0, root.maximumRowsPerSection);
    }

    function liveStatus(match) {
        if (String(match && match.sport || "").toLowerCase() === "basketball") {
            const period = SportsApi.liveStatusText("basketball", match && (match.minute || match.statusText));
            return period.length > 0 ? i18nc("@info:live match status", "Live %1", period) : i18nc("@info:live match status", "Live");
        }

        const minute = SportsApi.normalizedLiveMinute(match && match.minute);
        return minute.length > 0 ? i18nc("@info:live match status", "Live %1", minute) : i18nc("@info:live match status", "Live");
    }

    function scoreText(match) {
        const home = String(match && match.homeScore || "").trim();
        const away = String(match && match.awayScore || "").trim();
        return (home.length > 0 ? home : "0") + " - " + (away.length > 0 ? away : "0");
    }

    implicitWidth: Kirigami.Units.gridUnit * 38
    implicitHeight: tooltipLayout.implicitHeight

    ColumnLayout {
        id: tooltipLayout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        SectionTitle {
            text: i18nc("@title:group", "Live")
            visible: liveRepeater.count > 0
        }

        Repeater {
            id: liveRepeater
            model: root.liveRows()

            MatchRow {
                required property var modelData

                match: modelData
                live: true
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: liveRepeater.count > 0 && upcomingRepeater.count > 0
        }

        SectionTitle {
            text: i18nc("@title:group", "Upcoming")
            visible: upcomingRepeater.count > 0
        }

        Repeater {
            id: upcomingRepeater
            model: root.upcomingRows()

            MatchRow {
                required property var modelData

                match: modelData
                live: false
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: liveRepeater.count === 0 && upcomingRepeater.count === 0
            text: i18nc("@info:tooltip", "No live or upcoming matches")
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
        }
    }

    component SectionTitle: PlasmaComponents.Label {
        Layout.fillWidth: true
        color: Kirigami.Theme.textColor
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }

    component MatchRow: RowLayout {
        id: matchRow

        required property var match
        required property bool live

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.preferredWidth: 7
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            Layout.preferredHeight: 7
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: liveDot

                anchors.fill: parent
                visible: matchRow.live
                radius: width / 2
                color: Kirigami.Theme.negativeTextColor

                SequentialAnimation on opacity {
                    running: liveDot.visible
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1
                        to: 0.25
                        duration: 650
                    }

                    NumberAnimation {
                        from: 0.25
                        to: 1
                        duration: 650
                    }
                }
            }
        }

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 7
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            text: parent.live ? root.liveStatus(parent.match) : String(parent.match.startTime || "")
            color: parent.live ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
            font.bold: parent.live
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
        }

        TeamBadge {
            sourceUrl: String(parent.match.homeBadge || "")
        }

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            text: String(parent.match.homeTeam || "")
            color: Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3.2
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            text: parent.live ? root.scoreText(parent.match) : "-"
            color: Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignHCenter
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            text: String(parent.match.awayTeam || "")
            color: Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            font.bold: true
        }

        TeamBadge {
            sourceUrl: String(parent.match.awayBadge || "")
        }
    }

    component TeamBadge: Item {
        required property string sourceUrl

        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Layout.preferredWidth

        TeamBadgeImage {
            anchors.fill: parent
            sourceUrl: parent.sourceUrl
            fallbackIcon: "emblem-favorite"
            fallbackOpacity: 0.45
        }
    }
}
