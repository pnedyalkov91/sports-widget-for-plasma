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

    property string homeTeam: ""
    property string awayTeam: ""
    property string homeScore: ""
    property string awayScore: ""
    property string minute: ""
    property string startTime: ""
    property string homeBadge: ""
    property string awayBadge: ""
    property bool live: false
    property bool showScore: true
    property bool selected: false

    readonly property color foregroundColor: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    readonly property string periodText: SportsApi.liveStatusText("basketball", root.minute)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.largeSpacing

        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.live && root.periodText.length > 0
                text: root.periodText
                color: Kirigami.Theme.negativeTextColor
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.startTime
                color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Kirigami.Units.smallSpacing

            TeamRow {
                team: root.homeTeam
                score: root.homeScore
                badge: root.homeBadge
            }

            TeamRow {
                team: root.awayTeam
                score: root.awayScore
                badge: root.awayBadge
            }
        }
    }

    component TeamRow: RowLayout {
        id: teamRow

        required property string team
        required property string score
        required property string badge

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        TeamBadgeImage {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            sourceUrl: teamRow.badge
            fallbackIcon: "emblem-favorite"
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: teamRow.team
            color: root.foregroundColor
            elide: Text.ElideRight
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            text: root.showScore && teamRow.score.length > 0 ? teamRow.score : "-"
            color: root.live ? Kirigami.Theme.negativeTextColor : root.foregroundColor
            horizontalAlignment: Text.AlignRight
            font.bold: true
            font.pixelSize: Kirigami.Units.gridUnit
        }
    }
}
