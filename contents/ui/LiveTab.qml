/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var liveModel
    property string favoriteTeam: ""
    property bool loading: false
    property int selectedIndex: 0

    signal matchSelected(int index)

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    ListView {
        id: liveList

        anchors.fill: parent
        clip: true
        spacing: 0
        model: root.liveModel
        boundsBehavior: Flickable.StopAtBounds
        readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        section.property: "leagueGroup"
        section.criteria: ViewSection.FullString
        section.delegate: RoundSectionHeader {
            width: liveList.contentColumnWidth
            text: section
        }

        EmptyState {
            anchors.fill: parent
            visible: liveList.count === 0 && !root.loading
            text: i18nc("@info:placeholder", "No live matches")
        }

        delegate: LiveMatchDelegate {
            width: liveList.contentColumnWidth
            sport: model.sport || ""
            league: model.league || ""
            homeTeam: model.homeTeam || ""
            awayTeam: model.awayTeam || ""
            homeScore: model.homeScore || ""
            awayScore: model.awayScore || ""
            status: model.status || ""
            minute: model.minute || ""
            startTime: model.startTime || ""
            stadium: model.stadium || ""
            homeBadge: model.homeBadge || ""
            awayBadge: model.awayBadge || ""
            poster: model.poster || ""
            popular: Boolean(model.popular)
            showScore: model.showScore !== false
            favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
            selected: index === root.selectedIndex
            expanded: index === liveList.expandedIndex
            matchPath: model.matchPath || ""
            liveUrl: model.liveUrl || ""
            detailsProvider: model.detailsProvider || ""
            espnLeagueSlug: model.espnLeagueSlug || ""
            espnEventId: model.espnEventId || ""
            onClicked: {
                root.matchSelected(index);
                liveList.expandedIndex = liveList.expandedIndex === index ? -1 : index;
            }
        }

        property int expandedIndex: -1
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
        visible: root.loading && liveList.count === 0
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Layout.preferredWidth
            running: root.loading
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: i18nc("@info:status", "Loading live matches")
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
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
                source: "media-playback-start"
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
