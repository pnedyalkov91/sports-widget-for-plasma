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
    property bool loading: false
    property int selectedIndex: 0
    property string emptyText: i18nc("@info:placeholder", "No scheduled matches")
    property string loadingText: i18nc("@info:status", "Loading schedules")
    property string emptyIconName: "view-calendar-day"

    signal matchSelected(int index)

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
            visible: scheduleList.count === 0 && !root.loading
            text: root.emptyText
            iconName: root.emptyIconName
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
            stadium: model.stadium || ""
            homeBadge: model.homeBadge
            awayBadge: model.awayBadge
            poster: model.poster
            popular: model.popular
            favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
            selected: index === root.selectedIndex
            onClicked: root.matchSelected(index)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
        visible: root.loading && scheduleList.count === 0
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Layout.preferredWidth
            running: root.loading
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: root.loadingText
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    component EmptyState: Item {
        property string text: ""
        property string iconName: "view-calendar-day"

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                source: parent.parent.iconName
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
