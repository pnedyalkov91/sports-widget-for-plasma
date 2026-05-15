/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var fixturesModel
    property string favoriteTeam: ""

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    ListView {
        id: fixturesList

        anchors.fill: parent
        clip: true
        spacing: 0
        model: root.fixturesModel

        EmptyState {
            anchors.fill: parent
            visible: fixturesList.count === 0
            text: i18nc("@info:placeholder", "No scores or fixtures")
        }

        delegate: FixtureRow {
            width: fixturesList.width
            homeTeam: model.homeTeam
            awayTeam: model.awayTeam
            homeScore: model.homeScore
            awayScore: model.awayScore
            status: model.status
            startTime: model.startTime
            matchday: model.matchday
            homeBadge: model.homeBadge
            awayBadge: model.awayBadge
            favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
        }
    }

    component EmptyState: Item {
        property string text: ""

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                source: "view-calendar-day"
                color: "#9db7be"
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: "#9db7be"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    component FixtureRow: Rectangle {
        property string homeTeam: ""
        property string awayTeam: ""
        property string homeScore: ""
        property string awayScore: ""
        property string status: ""
        property string startTime: ""
        property string matchday: ""
        property string homeBadge: ""
        property string awayBadge: ""
        property bool favorite: false

        function scoreText(home, away) {
            if (home.length === 0 && away.length === 0)
                return "-";

            return home + " - " + away;
        }

        height: Kirigami.Units.gridUnit * 3
        color: favorite ? Qt.rgba(1, 0.59, 0.31, 0.14) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
                text: startTime
                color: "#9db7be"
                elide: Text.ElideRight
            }

            TeamCompact {
                Layout.fillWidth: true
                name: homeTeam
                badge: homeBadge
            }

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                text: scoreText(homeScore, awayScore)
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
            }

            TeamCompact {
                Layout.fillWidth: true
                name: awayTeam
                badge: awayBadge
            }

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                text: status
                color: status === "Live" ? "#6ee7a7" : "#9db7be"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }

    component TeamCompact: RowLayout {
        property string name: ""
        property string badge: ""

        spacing: Kirigami.Units.smallSpacing

        Image {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            source: badge
            visible: badge.length > 0
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: name
            color: "#e7fbff"
            elide: Text.ElideRight
        }
    }
}
