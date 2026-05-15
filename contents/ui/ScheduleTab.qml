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

    property var scheduleModel
    property string favoriteTeam: ""

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    ListView {
        id: scheduleList

        anchors.fill: parent
        clip: true
        spacing: 0
        model: root.scheduleModel

        EmptyState {
            anchors.fill: parent
            visible: scheduleList.count === 0
            text: i18nc("@info:placeholder", "No scheduled matches")
        }

        delegate: ScoreDelegate {
            width: scheduleList.width
            sport: model.sport
            league: model.league
            homeTeam: model.homeTeam
            awayTeam: model.awayTeam
            homeScore: model.homeScore
            awayScore: model.awayScore
            status: model.status
            minute: model.minute
            startTime: model.startTime
            homeBadge: model.homeBadge
            awayBadge: model.awayBadge
            poster: model.poster
            popular: model.popular
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
}
